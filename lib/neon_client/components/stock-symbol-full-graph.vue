<template>
  <svg ref="chart" />
</template>

<script>
import * as d3 from 'd3'

import { add, endOfDay, set, sub } from 'date-fns'

function remToPixels (rems = 1) {
  return rems * parseFloat(getComputedStyle(document.documentElement).fontSize)
}

export default {
  props: {
    aggregates: {
      type: Array,
      default: () => ([])
    },

    timeframe: {
      type: String,
      default: '24h',
      validator: (v) => ['24h', '48h', '7d', '14d'].includes(v)
    }
  },

  data: () => ({
    currentDate: new Date(),
    currentDateInterval: null
  }),

  computed: {
    xMax () {
      switch (this.timeframe) {
        case '14d':
          return endOfDay(add(this.currentDate, { hours: 8 }))

        case '7d':
          return endOfDay(add(this.currentDate, { hours: 4 }))

        case '48h':
          return add(this.currentDate, { hours: 4 })

        default:
          return add(this.currentDate, { hours: 2 })
      }
    },

    xMin () {
      switch (this.timeframe) {
        case '14d':
          return sub(this.currentDate, { days: 14 })

        case '7d':
          return sub(this.currentDate, { days: 7 })

        case '48h':
          return sub(this.currentDate, { hours: 48 })

        default:
          return sub(this.currentDate, { hours: 24 })
      }
    }
  },

  watch: {
    aggregates: {
      deep: true,
      handler () {
        this.clearGraph()
        this.drawGraph()
      }
    },

    currentDate: {
      deep: true,
      handler () {
        this.clearGraph()
        this.drawGraph()
      }
    }
  },

  created () {
    this.currentDateInterval = setInterval(() => {
      this.currentDate = new Date()
    }, 60000)
  },

  mounted () {
    this.drawGraph()
  },

  beforeDestroy () {
    clearInterval(this.currentDateInterval)
  },

  beforeUnmounted () {
    this.clearGraph()
  },

  methods: {
    clearGraph () {
      d3.select(this.$refs.chart)
        .selectAll('*')
        .remove()
    },

    drawGraph () {
      const { height, width } = this.$refs.chart.getBoundingClientRect()

      const x = d3.scaleTime()
        .domain([this.xMin, this.xMax])
        .range([0, width])

      const yMin = d3.min(this.aggregates, d => d.openPrice)
      const yMax = d3.max(this.aggregates, d => d.closePrice)
      const yPadding = (yMax - yMin) * 0.05

      const y = d3.scaleLinear()
        .domain([yMin - yPadding, yMax + yPadding])
        .range([height - remToPixels(1) , 0])

      const aggregateLine = window.line = d3.select(this.$refs.chart)
        .append('path')
        .datum(this.aggregates)
        .attr('class', 'line')
        .attr('fill', 'none')
        .attr('stroke', 'var(--accent)')
        .attr('d', d3.line()
          .x(d => x(d.insertedAt))
          .y(d => y(d.openPrice))
        )

      const mainTooltipPos = this.mainTooltipPosition(x, y)

      const tooltipLine = d3.select(this.$refs.chart)
        .append('line')
        .datum(this.aggregates)
        .attr('stroke', 'var(--blueberry-300)')
        .attr('x1', mainTooltipPos.x)
        .attr('y1', 6)
        .attr('x2', mainTooltipPos.x)
        .attr('y2', height - remToPixels(1) - 6)
        .attr('opacity', (mainTooltipPos.x == null) ? 0 : 1)

      const tooltipCircle = d3.select(this.$refs.chart)
        .append('circle')
        .datum(this.aggregates)
        .attr('fill', 'var(--blueberry-300)')
        .attr('r', 6)
        .attr('cx', mainTooltipPos.x)
        .attr('cy', mainTooltipPos.y)
        .attr('opacity', (mainTooltipPos.x == null) ? 0 : 1)

      d3.select(this.$refs.chart)
        .on('mousemove', (e) => {
          const [mouseX, mouseY] = d3.pointer(e)
          const { y: tooltipY } = this.valueAtX(aggregateLine, mouseX)

          const transition = d3.transition()
            .delay(0)
            .duration(40)
            .ease(d3.easeLinear)

          tooltipLine
            .transition(transition)
            .attr('x1', mouseX)
            .attr('x2', mouseX)
            .attr('opacity', 1)

          tooltipCircle
            .transition(transition)
            .attr('cx', mouseX)
            .attr('opacity', (tooltipY == null) ? 0 : 1)

          if (tooltipY != null) {
            tooltipCircle
              .transition(transition)
              .attr('cy', tooltipY)
          }
        })
        .on('mouseleave', () => {
          const transition = d3.transition()
            .delay(0)
            .duration(40)
            .ease(d3.easeLinear)

          tooltipLine
            .transition(transition)
            .attr('x1', mainTooltipPos.x)
            .attr('x2', mainTooltipPos.x)
            .attr('opacity', (mainTooltipPos.x == null) ? 0 : 1)

          tooltipCircle
            .transition(transition)
            .attr('cx', mainTooltipPos.x)
            .attr('cy', mainTooltipPos.y)
            .attr('opacity', (mainTooltipPos.x == null) ? 0 : 1)
        })
    },

    mainTooltipPosition (x, y) {
      const index = d3.maxIndex(this.aggregates, d => d.insertedAt)

      if (index === -1) {
        return { x: null, y: null }
      } else {
        return {
          x: x(this.aggregates[index].insertedAt),
          y: y(this.aggregates[index].openPrice)
        }
      }
    },

    valueAtX (line, x) {
      let loopStart = 0
      let loopCurrent = 0
      let loopEnd = line.node().getTotalLength()

      if (loopEnd === 0) {
        return { x, y: null }
      }

      const firstPoint = line.node().getPointAtLength(loopStart)
      const lastPoint = line.node().getPointAtLength(loopEnd)

      if (x < firstPoint.x || x > lastPoint.x) {
        return { x, y: null }
      }

      let current = { x: 0, y: 0 }

      while (true) {
        loopCurrent = Math.floor((loopStart + loopEnd) / 2)
        current = line.node().getPointAtLength(loopCurrent)

        if (loopCurrent === loopStart || loopCurrent === loopEnd) {
          break
        } else if (current.x > x) {
          loopEnd = loopCurrent
        } else if (current.x < x) {
          loopStart = loopCurrent
        } else {
          break
        }
      }

      return current
    }
  }
}
</script>
