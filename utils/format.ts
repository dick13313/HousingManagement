export function formatCurrency(value: number | string | null | undefined) {
  const amount = Number(value || 0)
  return new Intl.NumberFormat('zh-TW', {
    style: 'currency',
    currency: 'TWD',
    maximumFractionDigits: 0
  }).format(amount)
}

export function formatDate(value: string | null | undefined) {
  if (!value) return '-'
  return value
}

export function getStatusTone(status: string) {
  const danger = ['overdue', 'failed', 'disabled']
  const warning = ['partial', 'ending_soon', 'pending', 'unbilled']
  const success = ['paid', 'sent', 'active', 'rented', 'occupied']

  if (danger.includes(status)) return 'danger'
  if (warning.includes(status)) return 'warning'
  if (success.includes(status)) return 'success'
  return 'muted'
}

export function statusLabel(status: string | null | undefined) {
  const labels: Record<string, string> = {
    vacant: '空屋',
    rented: '出租中',
    occupied: '出租中',
    disabled: '停用',
    active: '生效中',
    ending_soon: '即將到期',
    ended: '已結束',
    unpaid: '未繳',
    partial: '部分繳',
    paid: '已繳',
    overdue: '逾期',
    pending: '待發送',
    unbilled: '待建帳',
    sent: '已發送',
    failed: '失敗',
    in_app: '系統內',
    email: 'Email',
    line: 'LINE',
    sms: '簡訊',
    cash: '現金',
    bank_transfer: '轉帳',
    check: '支票',
    other: '其他'
  }

  if (!status) return '-'
  return labels[status] || status
}
