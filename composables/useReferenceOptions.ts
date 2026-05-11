import type { FieldOption } from '~/types/management'

export function useReferenceOptions() {
  const { client } = useSupabaseClientLite()
  const owners = ref<FieldOption[]>([])
  const buildings = ref<FieldOption[]>([])
  const tenants = ref<FieldOption[]>([])
  const properties = ref<FieldOption[]>([])
  const leases = ref<FieldOption[]>([])
  const invoices = ref<FieldOption[]>([])

  async function loadOptions() {
    if (!client) return

    const [
      ownersResult,
      buildingsResult,
      tenantsResult,
      propertiesResult,
      leasesResult,
      invoicesResult
    ] = await Promise.all([
      client.from('owners').select('id, name').order('name'),
      client.from('buildings').select('id, name').order('name'),
      client.from('tenants').select('id, name').order('name'),
      client.from('properties').select('id, address, unit_no').order('address'),
      client.from('leases').select('id, tenants(name), properties(address)').order('created_at', { ascending: false }),
      client.from('rent_invoices').select('id, invoice_month, amount_due, leases(tenants(name))').order('due_on', { ascending: false })
    ])

    owners.value = (ownersResult.data || []).map((item) => ({ label: item.name, value: item.id }))
    buildings.value = (buildingsResult.data || []).map((item) => ({ label: item.name, value: item.id }))
    tenants.value = (tenantsResult.data || []).map((item) => ({ label: item.name, value: item.id }))
    properties.value = (propertiesResult.data || []).map((item) => ({
      label: [item.address, item.unit_no].filter(Boolean).join(' '),
      value: item.id
    }))
    leases.value = (leasesResult.data || []).map((item: any) => ({
      label: `${item.tenants?.name || '租客'} - ${item.properties?.address || '房屋'}`,
      value: item.id
    }))
    invoices.value = (invoicesResult.data || []).map((item: any) => ({
      label: `${item.leases?.tenants?.name || '租客'} - ${item.invoice_month} - ${formatCurrency(item.amount_due)}`,
      value: item.id
    }))
  }

  onMounted(loadOptions)

  return {
    owners,
    buildings,
    tenants,
    properties,
    leases,
    invoices,
    loadOptions
  }
}
