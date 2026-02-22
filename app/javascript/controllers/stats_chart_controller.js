import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "dataSource"]
  static values = { yLabel: { type: String, default: "Unique agents" } }

  connect() {
    if (typeof window.Chart === "undefined") return
    if (!this.hasCanvasTarget || !this.hasDataSourceTarget) return

    const raw = this.dataSourceTarget.textContent.trim()
    if (!raw) return

    let data
    try {
      data = JSON.parse(raw)
    } catch {
      return
    }

    const labels = data.labels || []
    const datasets = (data.datasets || []).map((ds, i) => {
      const colors = [
        "rgba(227, 179, 65, 0.9)",
        "rgba(88, 166, 255, 0.9)",
        "rgba(72, 187, 120, 0.9)",
        "rgba(210, 153, 234, 0.9)"
      ]
      const color = colors[i % colors.length]
      return {
        label: ds.label || ds.server_id,
        data: ds.data || [],
        borderColor: color,
        backgroundColor: color.replace("0.9", "0.2"),
        fill: true,
        tension: 0.2
      }
    })

    this.chart = new window.Chart(this.canvasTarget, {
      type: "line",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { position: "top" }
        },
        scales: {
          x: {
            ticks: {
              maxTicksLimit: 12,
              callback: (value, index) => {
                const label = labels[index]
                if (label == null) return ""
                const d = new Date(label)
                if (isNaN(d.getTime())) return label
                return d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit", timeZone: "UTC" })
              }
            },
            title: { display: false }
          },
          y: {
            beginAtZero: true,
            title: { display: true, text: this.yLabelValue }
          }
        }
      }
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }
}
