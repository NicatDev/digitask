import React from 'react';
import { Input, Button, Select, Grid, DatePicker } from 'antd';
import { FilterOutlined } from '@ant-design/icons';
import { TASK_STATUSES } from '../../constants';

const { Option } = Select;
const { RangePicker } = DatePicker;

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
    customers,
    groups = [],
    users,
    onNewTask,
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

                <Button
                    type="primary"
                    onClick={onNewTask}
                    disabled={disableCreate}
                    style={{
                        marginLeft: screens.md ? 'auto' : 0,
                        flex: screens.md ? 'none' : '1 1 100%',
                    }}
                >
                    Yeni Tapşırıq
                </Button>
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
                    <Select
                        placeholder="Müştəri"
                        style={{ width: screens.md ? 160 : 0, flex: screens.md ? 'none' : '1 1 100%' }}
                        allowClear
                        showSearch
                        optionFilterProp="children"
                        value={customerFilter}
                        onChange={setCustomerFilter}
                    >
                        {customers.map(c => (
                            <Option key={c.id} value={c.id}>{c.full_name}</Option>
                        ))}
                    </Select>

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
