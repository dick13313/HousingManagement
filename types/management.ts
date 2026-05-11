export type FieldOption = {
  label: string
  value: string
}

export type FormField = {
  key: string
  label: string
  type?: 'text' | 'email' | 'tel' | 'date' | 'number' | 'textarea' | 'select'
  required?: boolean
  valueType?: 'string' | 'number'
  options?: FieldOption[]
}

export type TableColumn = {
  key: string
  label: string
  align?: 'left' | 'right'
  status?: boolean
  format?: (row: Record<string, any>) => string
}

export type TableFilter = {
  key: string
  label: string
  options: FieldOption[]
}

export type StatusTone = 'success' | 'warning' | 'danger' | 'muted'
