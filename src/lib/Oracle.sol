// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

library Oracle {
    /// @dev Stores a price, the timestamp when this price was recorded,
    /// and the initialized flag that is set to true when the observation
    /// is activated (not all observations are activated by default).
    /// A pool contract can store up to 65,535 observations
    struct Observation {
        uint32 timestamp;
        int56 tickCumulative;
        bool initialize;
    }

    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 cardinalityNext)
    {
        self[0] = Observation({
            timestamp: time,
            tickCumulative: 0,
            initialize: true
        });

        cardinality = 1;
        cardinalityNext = 1;
    }

    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 timestamp,
        int24 tick,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = self[index];

        // Skipp when there’s already an observation made at the current block
        if (last.timestamp == timestamp) return (index, cardinality);

        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        // The modulo operator (%) ensures that observation index stays within the range
        // [0, cardinality) and resets to 0 when the upper bound is reached
        indexUpdated = (index + 1) % cardinalityUpdated;
        self[indexUpdated] = transform(last, timestamp, tick);
    }

    function transform(
        Observation memory last,
        uint32 timestamp,
        int24 tick
    ) internal pure returns (Observation memory) {
        uint56 delta = timestamp - last.timestamp;

        return
            Observation({
                timestamp: timestamp,
                // tick = (accumulatedTick2 - accumulatedTick1)/(t2 - t1)
                tickCumulative: last.tickCumulative +
                    int56(tick) *
                    int56(delta),
                initialize: true
            });
    }

    function grow(
        Observation[65535] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        if(next <= current) return current;

        for(uint16 i = current; i < next; i++) {
            // We’re allocating new observations by setting the timestamp field of each
            // of them to some non- zero value.
            self[i].timestamp = 1;
        }

        return next;
    }

    /// @dev  reading observations means finding observations by timestamps and interpolating missing observations
    function observe(
        Observation[65535] storage self,
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint16 index,
        uint16 cardinality
    ) internal view returns (int56[] memory tickCumulatives) {
        tickCumulatives = new int56[](secondsAgos.length);

        for(uint256 i = 0; i < secondsAgos.length; i++) {
            tickCumulatives[i] = observeSingle(
                self,
                time,
                secondsAgos[i],
                tick,
                index,
                cardinality
            );
        }
    }

    function observeSingle(
        Observation[65535] storage self, 
        uint32 time, 
        uint32 secondsAgos,
        int24 tick,
        uint16 index,
        uint16 cardinality
        ) internal view returns (int56 tickCumulative) {
    }

    function getSurroundingObservations(
        Observation[65535] storage self, 
        uint32 time, 
        uint32 target,
        int24 tick,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        beforeOrAt = self[index];

        // if target is at of after the last observation
        if(lte(time, beforeOrAt.timestamp, target)) {
            // target == the last observation
            if(beforeOrAt.timestamp == target) {
                return (beforeOrAt, atOrAfter);
            } else {
                return (beforeOrAt, transform(beforeOrAt, target, tick));
            }
        }

        
    }

    function binarySearch(
        Observation[65535] storage self, 
        uint32 time, 
        uint32 target,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        uint256 l = (index + 1) % cardinality; // oldest observation
        uint256 r = l + cardinality - 1; // newest observation
        uint256 i;
        while(true) {
            i = (l + r) / 2;

            beforeOrAt = self[i % cardinality];

            if(!beforeOrAt.initialize) {
                l = i + 1;
                continue;
            } 

            atOrAfter = self[(i + 1) % cardinality];

            bool targetAtOrAfter = lte(time, beforeOrAt.timestamp, target);

            if (targetAtOrAfter && lte(time, target, atOrAfter.timestamp)) {
                break;
            }

            if (!targetAtOrAfter) {
                r = i - 1;
            } else {
                l = i + 1;
            }
        }
    }

    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // if there hasn't been overflow, no need to adjust
        if(a <= time && b <= time) return a <= b;

        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }
}
