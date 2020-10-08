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
    </header>

    <div class="graph">
      <svg ref="chart" />
    </div>

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

  .graph svg {
    height: 100%;
    width: 100%;
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

  .graph {
    height: 60vh;
    margin: 1rem 0;
    width: 100%;
  }
</style>

<script>
import anime from 'animejs'
import * as d3 from 'd3'
import gql from 'graphql-tag'
import { faAngleUp } from '@fortawesome/free-solid-svg-icons'
import { startOfDay, startOfWeek, startOfMonth, startOfYear } from 'date-fns'

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
          from: this.fromDate,
          width: this.width
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
            width: this.width
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

    timeframe: 'day',
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

    fromDate () {
      switch (this.timeframe) {
        case 'week':
          return startOfWeek(new Date())

        case 'month':
          return startOfMonth(new Date())

        case 'year':
          return startOfYear(new Date())

        default:
          return startOfDay(new Date())
      }
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
    },

    width () {
      switch (this.timeframe) {
        case 'week':
          return '1 hour'

        case 'month':
          return '12 hours'

        case 'year':
          return '5 day'

        default:
          return '5 minutes'
      }
    }
  },

  watch: {
    aggregateData: {
      deep: true,
      handler () {
        this.drawGraph()
      }
    },

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
    },

    drawGraph () {
      const { height, width } = this.$refs.chart.getBoundingClientRect()
      const svg = d3.select(this.$refs.chart)

      const marginLeft = 60
      const marginBottom = 30

      svg.selectAll('*').remove()

      const x = d3.scaleTime()
        .domain(d3.extent(this.aggregateData, d => d.insertedAt))
        .range([0, width - marginLeft])

      svg.append('g')
        .attr('transform', `translate(${marginLeft}, ${height - marginBottom})`)
        .call(d3.axisBottom(x))

      const y = d3.scaleLinear()
        .domain([
          d3.min(this.aggregateData, d => d.openPrice) - 10,
          d3.max(this.aggregateData, d => d.openPrice) + 10
        ])
        .range([height - marginBottom, 0])

      svg.append('g')
        .attr('transform', `translate(${marginLeft}, 0)`)
        .call(d3.axisLeft(y))

      svg.append('path')
        .datum(this.aggregateData)
        .attr('transform', `translate(${marginLeft}, 0)`)
        .attr('fill', 'none')
        .attr('stroke', 'var(--accent)')
        .attr('stroke-width', 1.5)
        .attr('d', d3.line()
          .x(d => x(d.insertedAt))
          .y(d => y(d.openPrice))
        )
    }
  }
}
</script>