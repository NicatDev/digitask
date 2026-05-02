import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Input, Button, Select, Grid, DatePicker, Spin } from 'antd';
import { FilterOutlined, InsertRowAboveOutlined } from '@ant-design/icons';
import { TASK_STATUSES } from '../../constants';
import { getCustomer, getCustomerOptions } from '../../../../../../axios/api/tasks';

const { Option } = Select;
const { RangePicker } = DatePicker;

const CustomerFilterRemoteSelect = ({ value, onChange }) => {
    const [open, setOpen] = useState(false);
    const [options, setOptions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [search, setSearch] = useState('');
    const [debouncedSearch, setDebouncedSearch] = useState('');
    const [page, setPage] = useState(1);
    const [hasNext, setHasNext] = useState(false);
    const lastRequestKeyRef = useRef('');

    useEffect(() => {
        const t = setTimeout(() => setDebouncedSearch(search), 350);
        return () => clearTimeout(t);
    }, [search]);

    const fetchPage = useCallback(async ({ nextPage, append }) => {
        const requestKey = `${debouncedSearch}::${nextPage}`;
        lastRequestKeyRef.current = requestKey;
        setLoading(true);
        try {
            const res = await getCustomerOptions({
                search: debouncedSearch || undefined,
                page: nextPage,
                page_size: 10,
            });
            if (lastRequestKeyRef.current !== requestKey) return;
            const results = res.data?.results || [];
            setHasNext(!!res.data?.next);
            setPage(nextPage);
            setOptions((prev) => {
                const incoming = results.map((r) => ({
                    value: r.id,
                    label: r.label || r.full_name,
                }));
                if (!append) return incoming;
                const merged = [...prev];
                const seen = new Set(merged.map((x) => x.value));
                for (const item of incoming) {
                    if (!seen.has(item.value)) merged.push(item);
                }
                return merged;
            });
        } finally {
            setLoading(false);
        }
    }, [debouncedSearch]);

    useEffect(() => {
        if (!open) return;
        fetchPage({ nextPage: 1, append: false });
    }, [open, debouncedSearch, fetchPage]);

    useEffect(() => {
        if (!value) return;
        if (options.some((o) => o.value === value)) return;
        (async () => {
            try {
                const res = await getCustomer(value);
                const c = res.data;
                const label = c?.register_number ? `${c.full_name} - ${c.register_number}` : c?.full_name;
                if (!label) return;
                setOptions((prev) => {
                    if (prev.some((o) => o.value === value)) return prev;
                    return [{ value, label }, ...prev];
                });
            } catch (_) {
                // ignore
            }
        })();
    }, [value, options]);

    const onPopupScroll = (e) => {
        const target = e.target;
        if (!target) return;
        const nearBottom = target.scrollTop + target.offsetHeight >= target.scrollHeight - 24;
        if (nearBottom && hasNext && !loading) {
            fetchPage({ nextPage: page + 1, append: true });
        }
    };

    return (
        <Select
            placeholder="Müştəri"
            style={{ width: 160 }}
            allowClear
            showSearch
            filterOption={false}
            value={value}
            onChange={onChange}
            onSearch={setSearch}
            onDropdownVisibleChange={setOpen}
            options={options}
            notFoundContent={loading ? <Spin size="small" /> : null}
            onPopupScroll={onPopupScroll}
        />
    );
};

const TaskToolbar = ({
    searchText,
    setSearchText,
    showFilters,
    setShowFilters,
    statusFilter,
    setStatusFilter,
    customerFilter,
    setCustomerFilter,
    groupFilter,
    setGroupFilter,
    assigneeFilter,
    setAssigneeFilter,
    dateRange,
    setDateRange,
    isActiveFilter,
    setIsActiveFilter,
    groups = [],
    users,
    onNewTask,
    onOpenColumnSettings = () => {},
    disableCreate = false
}) => {
    const screens = Grid.useBreakpoint();

    const hasActiveFilters = customerFilter || groupFilter || assigneeFilter || dateRange || isActiveFilter !== true;

    return (
        <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px' }}>
            {/* Main Row — search, status, filter toggle, new task */}
            <div style={{
                display: 'flex',
                flexWrap: 'wrap',
                gap: '8px',
                alignItems: 'center',
            }}>
                <Input.Search
                    placeholder="Başlıq, Qeydiyyat No..."
                    value={searchText}
                    onChange={(e) => setSearchText(e.target.value)}
                    style={{ width: screens.md ? 220 : '100%', flex: screens.md ? 'none' : '1 1 100%' }}
                />

                <Select
                    placeholder="Status"
                    style={{ width: screens.md ? 140 : 0, flex: screens.md ? 'none' : '1 1 calc(50% - 4px)' }}
                    allowClear
                    value={statusFilter}
                    onChange={setStatusFilter}
                >
                    {TASK_STATUSES.map(s => (
                        <Option key={s.value} value={s.value}>
                            <span style={{ color: s.color, marginRight: 8 }}>●</span>
                            {s.label}
                        </Option>
                    ))}
                </Select>

                <Button
                    icon={<FilterOutlined />}
                    onClick={() => setShowFilters(!showFilters)}
                    type={showFilters || hasActiveFilters ? 'primary' : 'default'}
                    ghost={showFilters || hasActiveFilters}
                    style={{ flex: screens.md ? 'none' : '1 1 calc(50% - 4px)' }}
                >
                    {screens.md ? 'Filtrlər' : 'Filter'}
                </Button>

                <div
                    style={{
                        marginLeft: screens.md ? 'auto' : 0,
                        display: 'flex',
                        flexWrap: 'wrap',
                        gap: 8,
                        flex: screens.md ? 'none' : '1 1 100%',
                    }}
                >
                    <Button
                        icon={<InsertRowAboveOutlined />}
                        onClick={onOpenColumnSettings}
                        style={{
                            flex: screens.md ? 'none' : '1 1 calc(50% - 4px)',
                        }}
                    >
                        Sütunlar
                    </Button>
                    <Button
                        type="primary"
                        onClick={onNewTask}
                        disabled={disableCreate}
                        style={{
                            flex: screens.md ? 'none' : '1 1 calc(50% - 4px)',
                        }}
                    >
                        Yeni Tapşırıq
                    </Button>
                </div>
            </div>

            {/* Expanded Filters */}
            {showFilters && (
                <div style={{
                    display: 'flex',
                    flexWrap: 'wrap',
                    gap: '8px',
                    marginTop: 12,
                    paddingTop: 12,
                    borderTop: '1px solid #f0f0f0',
                    alignItems: 'center',
                }}>
                    <div style={{ width: screens.md ? 160 : '100%', flex: screens.md ? 'none' : '1 1 100%' }}>
                        <CustomerFilterRemoteSelect value={customerFilter} onChange={setCustomerFilter} />
                    </div>

                    <Select
                        placeholder="Qrup"
                        style={{ width: screens.md ? 160 : 0, flex: screens.md ? 'none' : '1 1 100%' }}
                        allowClear
                        showSearch
                        optionFilterProp="children"
                        value={groupFilter}
                        onChange={setGroupFilter}
                    >
                        {groups.map(g => (
                            <Option key={g.id} value={g.id}>{g.name}</Option>
                        ))}
                    </Select>

                    <Select
                        placeholder="İcraçı"
                        style={{ width: screens.md ? 160 : 0, flex: screens.md ? 'none' : '1 1 100%' }}
                        allowClear
                        showSearch
                        optionFilterProp="children"
                        value={assigneeFilter}
                        onChange={setAssigneeFilter}
                    >
                        {users.map(u => (
                            <Option key={u.id} value={u.id}>
                                {u.first_name} {u.last_name}
                            </Option>
                        ))}
                    </Select>

                    <RangePicker
                        placeholder={['Başlanğıc', 'Son']}
                        style={{ width: screens.md ? 230 : '100%' }}
                        value={dateRange}
                        onChange={setDateRange}
                    />

                    <Select
                        placeholder="Aktivlik"
                        style={{ width: screens.md ? 110 : 0, flex: screens.md ? 'none' : '1 1 100%' }}
                        allowClear={false}
                        value={isActiveFilter}
                        onChange={setIsActiveFilter}
                    >
                        <Option value="all">Hamısı</Option>
                        <Option value={true}>Aktiv</Option>
                        <Option value={false}>Deaktiv</Option>
                    </Select>
                </div>
            )}
        </div>
    );
};

export default TaskToolbar;
