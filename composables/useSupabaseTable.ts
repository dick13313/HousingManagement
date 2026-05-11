type LoadOptions = {
  select?: string
  order?: string
  ascending?: boolean
}

function normalizePayload(payload: Record<string, any>) {
  return Object.fromEntries(
    Object.entries(payload).map(([key, value]) => {
      if (value === '') return [key, null]
      return [key, value]
    })
  )
}

async function deleteById(client: any, table: string, id: string) {
  const { error } = await client.from(table).delete().eq('id', id)
  if (error) throw error
}

async function deleteWhereIn(client: any, table: string, column: string, ids: string[]) {
  if (ids.length === 0) return
  const { error } = await client.from(table).delete().in(column, ids)
  if (error) throw error
}

async function selectIds(client: any, table: string, column: string, id: string) {
  const { data, error } = await client.from(table).select('id').eq(column, id)
  if (error) throw error
  return (data || []).map((row: { id: string }) => row.id)
}

async function cascadeDeleteInvoice(client: any, invoiceId: string) {
  await deleteWhereIn(client, 'reminders', 'rent_invoice_id', [invoiceId])
  await deleteWhereIn(client, 'payments', 'rent_invoice_id', [invoiceId])
  await deleteById(client, 'rent_invoices', invoiceId)
}

async function cascadeDeleteLease(client: any, leaseId: string) {
  const invoiceIds = await selectIds(client, 'rent_invoices', 'lease_id', leaseId)
  for (const invoiceId of invoiceIds) {
    await cascadeDeleteInvoice(client, invoiceId)
  }
  await deleteById(client, 'leases', leaseId)
}

async function cascadeDeleteProperty(client: any, propertyId: string) {
  const leaseIds = await selectIds(client, 'leases', 'property_id', propertyId)
  for (const leaseId of leaseIds) {
    await cascadeDeleteLease(client, leaseId)
  }
  await deleteById(client, 'properties', propertyId)
}

async function cascadeDeleteTenant(client: any, tenantId: string) {
  const leaseIds = await selectIds(client, 'leases', 'tenant_id', tenantId)
  for (const leaseId of leaseIds) {
    await cascadeDeleteLease(client, leaseId)
  }
  await deleteWhereIn(client, 'reminders', 'tenant_id', [tenantId])
  await deleteById(client, 'tenants', tenantId)
}

async function cascadeDeleteBuilding(client: any, buildingId: string) {
  const propertyIds = await selectIds(client, 'properties', 'building_id', buildingId)
  for (const propertyId of propertyIds) {
    await cascadeDeleteProperty(client, propertyId)
  }
  await deleteById(client, 'buildings', buildingId)
}

async function cascadeDeleteOwner(client: any, ownerId: string) {
  const propertyIds = await selectIds(client, 'properties', 'owner_id', ownerId)
  for (const propertyId of propertyIds) {
    await cascadeDeleteProperty(client, propertyId)
  }

  await client.from('profiles').update({ owner_id: null }).eq('owner_id', ownerId)
  await deleteById(client, 'owners', ownerId)
}

async function cascadeDelete(client: any, tableName: string, id: string) {
  switch (tableName) {
    case 'owners':
      await cascadeDeleteOwner(client, id)
      return
    case 'buildings':
      await cascadeDeleteBuilding(client, id)
      return
    case 'properties':
      await cascadeDeleteProperty(client, id)
      return
    case 'tenants':
      await cascadeDeleteTenant(client, id)
      return
    case 'leases':
      await cascadeDeleteLease(client, id)
      return
    case 'rent_invoices':
      await cascadeDeleteInvoice(client, id)
      return
    default:
      await deleteById(client, tableName, id)
  }
}

function friendlyDeleteError(message: string) {
  if (message.includes('violates foreign key constraint')) {
    return '這筆資料仍有關聯紀錄，系統無法直接移除。請先移除關聯資料，或使用管理員帳號重新嘗試。'
  }

  if (message.includes('permission denied') || message.includes('violates row-level security')) {
    return '目前帳號沒有移除這筆資料的權限。'
  }

  return message
}

export function useSupabaseTable(tableName: string, options: LoadOptions = {}) {
  const { client, isConfigured } = useSupabaseClientLite()
  const rows = ref<Record<string, any>[]>([])
  const loading = ref(false)
  const saving = ref(false)
  const error = ref('')

  async function load() {
    error.value = ''

    if (!client) {
      rows.value = []
      return
    }

    const { data: sessionData } = await client.auth.getSession()
    if (!sessionData.session) {
      rows.value = []
      return
    }

    loading.value = true

    const query = client
      .from(tableName)
      .select(options.select || '*')

    if (options.order) {
      query.order(options.order, { ascending: options.ascending ?? true })
    }

    const { data, error: loadError } = await query
    loading.value = false

    if (loadError) {
      error.value = loadError.message
      return
    }

    rows.value = data || []
  }

  async function create(payload: Record<string, any>) {
    error.value = ''

    if (!client) {
      error.value = '尚未設定 Supabase 連線資訊。'
      return false
    }

    const { data: sessionData } = await client.auth.getSession()
    if (!sessionData.session) {
      error.value = '請先登入。'
      return false
    }

    saving.value = true
    const { error: createError } = await client
      .from(tableName)
      .insert(normalizePayload(payload))

    saving.value = false

    if (createError) {
      error.value = createError.message
      return false
    }

    await load()
    return true
  }

  async function update(id: string, payload: Record<string, any>) {
    error.value = ''

    if (!client) {
      error.value = '尚未設定 Supabase 連線資訊。'
      return false
    }

    const { data: sessionData } = await client.auth.getSession()
    if (!sessionData.session) {
      error.value = '請先登入。'
      return false
    }

    saving.value = true
    const { error: updateError } = await client
      .from(tableName)
      .update(normalizePayload(payload))
      .eq('id', id)

    saving.value = false

    if (updateError) {
      error.value = updateError.message
      return false
    }

    await load()
    return true
  }

  async function remove(id: string) {
    error.value = ''

    if (!client) {
      error.value = '尚未設定 Supabase 連線資訊。'
      return false
    }

    const { data: sessionData } = await client.auth.getSession()
    if (!sessionData.session) {
      error.value = '請先登入。'
      return false
    }

    saving.value = true
    try {
      await cascadeDelete(client, tableName, id)
    } catch (deleteError: any) {
      error.value = friendlyDeleteError(deleteError.message || '移除失敗。')
      saving.value = false
      return false
    }

    saving.value = false
    await load()
    return true
  }

  onMounted(load)

  return {
    rows,
    loading,
    saving,
    error,
    isConfigured,
    load,
    create,
    update,
    remove
  }
}
