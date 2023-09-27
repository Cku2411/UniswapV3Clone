// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library Oracle {
    // Struct that stores a record Price.
    struct Observation {
        uint32 timestamp; // timeStamp when price is recorded
        int56 tickCumulative;
        bool initialized; // set true when observation is active.
    }

    function initialize(
        Observation[65535] storage self,
        uint32 time
    ) internal returns (uint16 cardinality, uint16 cardinalityNext) {
        self[0] = Observation({
            timestamp: time,
            tickCumulative: 0,
            initialized: true
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
        // get the observation
        Observation memory last = self[index];
        if (last.timestamp == timestamp) return (index, cardinality);

        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        // make sure observation index statys within the range (0, cardinality)
        indexUpdated = (index + 1) % cardinalityUpdated;
        self[indexUpdated] = transform(last, timestamp, tick);
    }

    function grow(
        Observation[65535] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        if (next <= current) return current;

        for (uint16 i = current; i < next; i++) {
            self[i].timestamp = 1;
        }
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
                tickCumulative: last.tickCumulative +
                    int56(tick) *
                    int56(delta),
                initialized: true
            });
    }
}
