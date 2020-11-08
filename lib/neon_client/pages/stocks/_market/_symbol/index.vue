<template>
  <div :class="['page', style]">
    <header>
      <h1>{{ symbol.symbol }}</h1>

      <span
        ref="price"
        class="price"
      >
        {{ animation.price | currency }}

        <font-awesome-icon :icon="faAngleUp" />

        {{ animation.diffPrice | currency }}
      </span>

      <dl>
        <dt>Change:</dt>
        <dd>{{ animation.percentage | percentage }}</dd>

        <dt>Volume:</dt>
        <dd>{{ animation.volume | round }}</dd>
      </dl>

      <button @click="timeframe = '24h'">
        24h
      </button>

      <button @click="timeframe = '48h'">
        48h
      </button>

      <button @click="timeframe = '7d'">
        7d
      </button>

      <button @click="timeframe = '14d'">
        14d
      </button>
    </header>

    <stock-symbol-full-graph
      class="graph"
      :aggregates="aggregateData"
      :timeframe="timeframe"
    />

    <div>
      <form-input
        id="days"
        v-model.number="days"
        label="days"
        type="number"
      />

      <form-button @click="backfill">
        Backfill
      </form-button>
    </div>
  </div>
</template>

<style scoped>
  .page {
    --accent: var(--first-bg-color);

    padding: 1rem;
  }

  .page.up {
    --accent: var(--lime-300);
  }

  .page.down {
    --accent: var(--strawberry-300);
  }

  header {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    align-content: flex-end;
    justify-content: flex-start;
  }

  h1 {
    margin: 0;
  }

  .price {
    color: var(--accent);
    font-size: 1.2rem;
    margin: 0 0 0 calc(4ch * 0.8);
    transition: color 400ms ease;
  }

  .price >>> svg {
    margin: 0 0.5ch;
    transform: rotate(270deg);
    transition: transform 400ms ease;
  }

  .page.up .price >>> svg {
    transform: rotate(0deg);
  }

  .page.down .price >>> svg {
    transform: rotate(180deg);
  }

  dl {
    display: flex;
  }

  dt {
    margin: 0 1ch 0 4ch;
  }

  dd {
    color: var(--accent);
  }

  .tooltip {
    background-color: black;
    border: 1px solid blue;
    padding: 1rem;
    position: absolute;
    top: 0;
    transform: translate(-50%, 0);
  }

  .graph {
    height: 60vh;
    margin: 1rem 0;
    width: 100%;
  }
</style>

<script>
import anime from 'animejs'
import * as d3 from 'd3'
import throttle from 'lodash/throttle'
import debounce from 'lodash/debounce'
import gql from 'graphql-tag'
import { faAngleUp } from '@fortawesome/free-solid-svg-icons'
import { set, sub, startOfDay } from 'date-fns'

import * as formatting from '~/filters/formatting'

export default {
  apollo: {
    aggregates: {
      query: gql`query($symbol: ID!, $width: String!, $from: DateTime!) {
        aggregates: stockAggregates(symbolId: $symbol, width: $width, from: $from){
          id
          openPrice
          highPrice
          lowPrice
          closePrice
          volume
          records
          insertedAt
        }
      }`,
      variables () {
        return {
          symbol: this.symbol.id,
          from: this.startTime,
          width: '5 minutes'
        }
      },
      skip () {
        return (this.symbol.id == null)
      },
      subscribeToMore: {
        document: gql`subscription ($symbol: ID!, $width: String!) {
          aggregate: stockNewAggregate(symbolId: $symbol, width: $width){
            id
            openPrice
            highPrice
            lowPrice
            closePrice
            volume
            records
            insertedAt
          }
        }`,
        variables () {
          return {
            symbol: this.symbol.id,
            width: '5 minutes'
          }
        },
        updateQuery: ({ aggregates }, { subscriptionData: { data: { aggregate } } }) => {
          const newAggregates = aggregates
            .filter(a => (a.insertedAt !== aggregate.insertedAt))
            .concat([aggregate])

          return { aggregates: newAggregates }
        }
      }
    },

    symbol: {
      query: gql`query($market: String!, $symbol: String!) {
        symbol: stockSymbol(marketAbbreviation: $market, symbol: $symbol) {
          id
          symbol
          market {
            id
            abbreviation
          }
        }
      }`,
      variables () {
        return {
          market: this.$route.params.market.toUpperCase(),
          symbol: this.$route.params.symbol.toUpperCase()
        }
      }
    }
  },

  filters: {
    ...formatting
  },

  data: () => ({
    faAngleUp,

    aggregates: [],
    symbol: {
      id: null
    },

    timeframe: '14d',
    days: 30,

    animation: {
      diffPrice: 0,
      percentage: 0,
      price: 0,
      volume: 0
    }
  }),

  computed: {
    aggregateData () {
      return this.aggregates
        .map(d => ({
          closePrice: Number(d.closePrice),
          highPrice: Number(d.highPrice),
          insertedAt: new Date(d.insertedAt),
          lowPrice: Number(d.lowPrice),
          openPrice: Number(d.openPrice),
          volume: Number(d.volume),
          records: Number(d.records)
        }))
        .sort((a, b) => (a.insertedAt - b.insertedAt))
    },

    dayTime: () => (hours, minutes = 0) => {
      return set(new Date(), { hours, minutes, seconds: 0, milliseconds: 0 })
    },

    diffPrice () {
      if (this.firstData != null && this.lastData != null) {
        return this.lastData.openPrice - this.firstData.openPrice
      } else {
        return 0
      }
    },

    firstData () {
      return this.aggregateData[0]
    },

    lastData () {
      return this.aggregateData[this.aggregateData.length - 1]
    },

    percentage () {
      if (this.firstData != null && this.lastData != null) {
        return (this.lastData.openPrice - this.firstData.openPrice) / this.lastData.openPrice * 100
      } else {
        return 0
      }
    },

    price () {
      if (this.lastData) {
        return this.lastData.openPrice
      } else {
        return 0
      }
    },

    startTime () {
      switch (this.timeframe) {
        case '14d':
          return sub(new Date(), { days: 14 })

        case '7d':
          return sub(new Date(), { days: 7 })

        case '48h':
          return sub(new Date(), { hours: 48 })

        default:
          return sub(new Date(), { hours: 24 })
      }
    },

    style () {
      if (this.diffPrice != null && this.diffPrice > 0) {
        return 'up'
      } else if (this.diffPrice != null && this.diffPrice < 0) {
        return 'down'
      } else {
        return null
      }
    },

    volume () {
      if (this.lastData != null) {
        return this.lastData.volume
      } else {
        return 0
      }
    }
  },

  watch: {
    diffPrice (diffPrice) {
      anime({
        targets: this.animation,
        diffPrice,
        round: 1000,
        easing: 'easeOutExpo',
        duration: 1000
      })
    },

    percentage (percentage) {
      anime({
        targets: this.animation,
        percentage,
        round: 1000,
        easing: 'easeOutExpo',
        duration: 1000
      })
    },

    price (price) {
      anime({
        targets: this.animation,
        price,
        round: 1000,
        easing: 'easeOutExpo',
        duration: 1000
      })
    },

    volume (volume) {
      anime({
        targets: this.animation,
        volume,
        round: 1000,
        easing: 'easeOutExpo',
        duration: 400
      })
    }
  },

  methods: {
    async backfill () {
      await this.$apollo.mutate({
        mutation: gql`mutation($symbol: String!, $days: Int!) {
          backfill: stockBackfill(symbolId: $symbol, days: $days) {
            __typename
          }
        }`,
        variables: {
          symbol: this.symbol.id,
          days: this.days
        }
      })
    }
  }
}
</script>
