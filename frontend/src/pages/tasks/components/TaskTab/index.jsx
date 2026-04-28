import React, { useEffect, useState, useRef } from 'react';
import { Form, message, Grid } from 'antd';
import dayjs from 'dayjs';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { getTasks, createTask, updateTask, deleteTask, updateTaskStatus, getServices, getColumns, getTaskTypes, addTaskAssignee, joinTask, markTaskExternalArchived } from '../../../../axios/api/tasks';
import { getGroups, getUsers } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';
import { useAuth } from '../../../../context/AuthContext';
import { hasTaskActionPermission, TASK_ACTIONS } from '../../../../utils/permissions';

// Components
import TaskModal from './TaskModal';
import QuestionnaireModal from './QuestionnaireModal/index';
import TaskToolbar from './components/TaskToolbar';
import TaskTable from './components/TaskTable';
import StatusModal from './components/StatusModal';
import MapModal from './components/MapModal';
import ProductSelectionModal from './components/ProductSelectionModal';
import DocumentModal from './components/DocumentModal';
import TaskDetailModal from './components/TaskDetailModal';
import AssigneeModal from './components/AssigneeModal';
import TaskAddressEditModal from './components/TaskAddressEditModal';

// Styles
import styles from './style.module.scss'; // Kept primarily for Status Badge styles used in Table

// Fix Leaflet Icons (global setup often best done in App root, but here works too)
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const TaskTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [groups, setGroups] = useState([]);
    const [users, setUsers] = useState([]);
    const [services, setServices] = useState([]);
    const [columns, setColumns] = useState([]);
    const [taskTypes, setTaskTypes] = useState([]);
    const [pagination, setPagination] = useState({
        current: 1,
        pageSize: 5,
        total: 0
    });

    const [loading, setLoading] = useState(false);
    const { user } = useAuth();

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState(null);
    const [customerFilter, setCustomerFilter] = useState(null);
    const [groupFilter, setGroupFilter] = useState(null);
    const [assigneeFilter, setAssigneeFilter] = useState(null);
    const [dateRange, setDateRange] = useState(null);
    const [isActiveFilter, setIsActiveFilter] = useState(true);
    const [showFilters, setShowFilters] = useState(false);

    /** Cədvəl: backend sıralama (null = standart status ardıcıllığı) */
    const [tableOrdering, setTableOrdering] = useState(null);
    const [columnIdSearch, setColumnIdSearch] = useState('');
    const [columnRegisterSearch, setColumnRegisterSearch] = useState('');

    const tableOrderingRef = useRef(null);
    const columnRegisterSearchRef = useRef('');
    const columnIdSearchRef = useRef('');
    const idSearchDebounceRef = useRef(null);
    const regSearchDebounceRef = useRef(null);

    useEffect(() => {
        tableOrderingRef.current = tableOrdering;
    }, [tableOrdering]);
    useEffect(() => {
        columnRegisterSearchRef.current = columnRegisterSearch;
    }, [columnRegisterSearch]);
    useEffect(() => {
        columnIdSearchRef.current = columnIdSearch;
    }, [columnIdSearch]);

    // Modal States
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isStatusModalOpen, setIsStatusModalOpen] = useState(false);
    const [isQuestionnaireModalOpen, setIsQuestionnaireModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [currentTaskForQuestionnaire, setCurrentTaskForQuestionnaire] = useState(null);
    const [selectedCoords, setSelectedCoords] = useState(null);
    const [isMapModalOpen, setIsMapModalOpen] = useState(false);
    const [viewingCoords, setViewingCoords] = useState(null);
    const [viewingCustomerName, setViewingCustomerName] = useState('');
    const [isProductModalOpen, setIsProductModalOpen] = useState(false);
    const [currentTaskForProducts, setCurrentTaskForProducts] = useState(null);
    const [isDocumentModalOpen, setIsDocumentModalOpen] = useState(false);
    const [currentTaskForDocuments, setCurrentTaskForDocuments] = useState(null);
    const [isDetailModalOpen, setIsDetailModalOpen] = useState(false);
    const [selectedTaskForDetail, setSelectedTaskForDetail] = useState(null);
    const [isAssigneeModalOpen, setIsAssigneeModalOpen] = useState(false);
    const [currentTaskForAssignee, setCurrentTaskForAssignee] = useState(null);
    const [isAddressEditOpen, setIsAddressEditOpen] = useState(false);
    const [addressEditCustomer, setAddressEditCustomer] = useState(null);

    const [form] = Form.useForm();
    const taskCaps = {
        canCreate: hasTaskActionPermission(user, TASK_ACTIONS.CREATE),
        canEditGeneral: hasTaskActionPermission(user, TASK_ACTIONS.EDIT_GENERAL),
        canDelete: hasTaskActionPermission(user, TASK_ACTIONS.DELETE),
        canChangeStatus: hasTaskActionPermission(user, TASK_ACTIONS.CHANGE_STATUS),
        canManageSurveys: hasTaskActionPermission(user, TASK_ACTIONS.MANAGE_SURVEYS),
        canManageProducts: hasTaskActionPermission(user, TASK_ACTIONS.MANAGE_PRODUCTS),
        canManageDocuments: hasTaskActionPermission(user, TASK_ACTIONS.MANAGE_DOCUMENTS),
        canManageAssignees: hasTaskActionPermission(user, TASK_ACTIONS.MANAGE_ASSIGNEES),
        canJoinTask: hasTaskActionPermission(user, TASK_ACTIONS.JOIN_TASK),
        canToggleActive: hasTaskActionPermission(user, TASK_ACTIONS.TOGGLE_ACTIVE),
    };

    // Debounce Search
    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async (params = {}) => {
        setLoading(true);
        try {
            // Prepare query params
            const queryParams = {
                page: params.page || pagination.current,
                page_size: params.pageSize || pagination.pageSize,
                search: params.search !== undefined ? params.search : debouncedSearchText,
                status: params.status !== undefined ? params.status : statusFilter,
                customer: params.customer !== undefined ? params.customer : customerFilter,
                group: params.group !== undefined ? params.group : groupFilter,
                assigned_to: params.assigned_to !== undefined ? params.assigned_to : assigneeFilter,
                is_active: params.is_active !== undefined ? (params.is_active === 'all' ? undefined : params.is_active) : (isActiveFilter === 'all' ? undefined : isActiveFilter),
                // Date range handling...
            };

            if (dateRange && dateRange[0]) {
                queryParams.date_from = dateRange[0].format('YYYY-MM-DD');
                queryParams.date_to = dateRange[1].format('YYYY-MM-DD');
            }

            const orderingVal = params.ordering !== undefined ? params.ordering : tableOrdering;
            if (orderingVal) {
                queryParams.ordering = orderingVal;
            }

            const idCol = params.id_search !== undefined ? params.id_search : columnIdSearch;
            if (idCol && String(idCol).trim()) {
                queryParams.id_search = String(idCol).trim();
            }

            const regCol =
                params.register_number_search !== undefined
                    ? params.register_number_search
                    : columnRegisterSearch;
            if (regCol && String(regCol).trim()) {
                queryParams.register_number_search = String(regCol).trim();
            }

            const [tasksRes, groupsRes, usersRes, servicesRes, columnsRes, taskTypesRes] = await Promise.all([
                getTasks(queryParams),
                getGroups(),
                getUsers(),
                getServices(),
                getColumns(),
                getTaskTypes()
            ]);

            // Handle paginated response
            const taskData = tasksRes.data;
            if (taskData.results) {
                setData(taskData.results);
                setPagination(prev => ({
                    ...prev,
                    current: queryParams.page,
                    pageSize: queryParams.page_size,
                    total: taskData.count
                }));
            } else {
                setData(taskData); // Fallback for non-paginated
            }

            setGroups(groupsRes.data.results || groupsRes.data);
            setUsers(usersRes.data.results || usersRes.data);
            setServices(servicesRes.data.results || servicesRes.data);
            setColumns(columnsRes.data.results || columnsRes.data);
            setTaskTypes(taskTypesRes.data.results || taskTypesRes.data);
        } catch (error) {
            console.error(error);
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    // Initial Fetch
    useEffect(() => {
        if (isActive) {
            fetchData();
        }
    }, [isActive]);

    // Refetch on filter changes
    useEffect(() => {
        if (isActive) {
            fetchData({ page: 1 });
        }
    }, [debouncedSearchText, statusFilter, customerFilter, groupFilter, assigneeFilter, isActiveFilter, dateRange]);

    const clearColumnSearchDebounces = () => {
        if (idSearchDebounceRef.current) {
            clearTimeout(idSearchDebounceRef.current);
            idSearchDebounceRef.current = null;
        }
        if (regSearchDebounceRef.current) {
            clearTimeout(regSearchDebounceRef.current);
            regSearchDebounceRef.current = null;
        }
    };

    const scheduleColumnIdSearch = (raw) => {
        const v = raw != null ? String(raw).trim() : '';
        if (idSearchDebounceRef.current) clearTimeout(idSearchDebounceRef.current);
        idSearchDebounceRef.current = setTimeout(() => {
            idSearchDebounceRef.current = null;
            setColumnIdSearch(v);
            fetchData({
                page: 1,
                id_search: v,
                register_number_search: columnRegisterSearchRef.current,
                ordering: tableOrderingRef.current,
            });
        }, 400);
    };

    const flushColumnIdSearch = (raw) => {
        if (idSearchDebounceRef.current) {
            clearTimeout(idSearchDebounceRef.current);
            idSearchDebounceRef.current = null;
        }
        const v = raw != null ? String(raw).trim() : '';
        setColumnIdSearch(v);
        fetchData({
            page: 1,
            id_search: v,
            register_number_search: columnRegisterSearchRef.current,
            ordering: tableOrderingRef.current,
        });
    };

    const scheduleColumnRegisterSearch = (raw) => {
        const v = raw != null ? String(raw).trim() : '';
        if (regSearchDebounceRef.current) clearTimeout(regSearchDebounceRef.current);
        regSearchDebounceRef.current = setTimeout(() => {
            regSearchDebounceRef.current = null;
            setColumnRegisterSearch(v);
            fetchData({
                page: 1,
                register_number_search: v,
                id_search: columnIdSearchRef.current,
                ordering: tableOrderingRef.current,
            });
        }, 400);
    };

    const flushColumnRegisterSearch = (raw) => {
        if (regSearchDebounceRef.current) {
            clearTimeout(regSearchDebounceRef.current);
            regSearchDebounceRef.current = null;
        }
        const v = raw != null ? String(raw).trim() : '';
        setColumnRegisterSearch(v);
        fetchData({
            page: 1,
            register_number_search: v,
            id_search: columnIdSearchRef.current,
            ordering: tableOrderingRef.current,
        });
    };

    const handleTableChange = (newPagination, _filters, sorter, extra) => {
        const s = Array.isArray(sorter) ? sorter[0] : sorter;
        const colKey = s?.columnKey ?? s?.field;
        const ord = s?.order;

        const nextPage = newPagination?.current ?? pagination.current;
        const nextPageSize = newPagination?.pageSize ?? pagination.pageSize;

        if (extra?.action === 'sort') {
            clearColumnSearchDebounces();
            let nextOrdering = null;
            if (colKey && (ord === 'ascend' || ord === 'descend')) {
                if (colKey === 'id') {
                    nextOrdering = ord === 'ascend' ? 'id' : '-id';
                } else if (colKey === 'customer_register_number') {
                    nextOrdering = ord === 'ascend' ? 'register_number' : '-register_number';
                }
            }
            setTableOrdering(nextOrdering);
            fetchData({ page: 1, pageSize: nextPageSize, ordering: nextOrdering });
            return;
        }

        if (extra?.action === 'paginate') {
            fetchData({ page: nextPage, pageSize: nextPageSize });
            return;
        }

        let nextOrdering = tableOrdering;
        if (colKey && (ord === 'ascend' || ord === 'descend')) {
            if (colKey === 'id') {
                nextOrdering = ord === 'ascend' ? 'id' : '-id';
            } else if (colKey === 'customer_register_number') {
                nextOrdering = ord === 'ascend' ? 'register_number' : '-register_number';
            }
        } else if (colKey && !ord) {
            nextOrdering = null;
        } else {
            nextOrdering = tableOrdering;
        }

        const sortChanged = nextOrdering !== tableOrdering;
        setTableOrdering(nextOrdering);
        fetchData({
            page: sortChanged ? 1 : nextPage,
            pageSize: nextPageSize,
            ordering: nextOrdering,
        });
    };

    const handleDelete = async (id) => {
        try {
            await deleteTask(id);
            message.success('Tapşırıq silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };


    const onFinish = async (values) => {
        try {
            const submitData = { ...values };
            if (submitData.rescheduled_date && dayjs.isDayjs(submitData.rescheduled_date)) {
                submitData.rescheduled_date = submitData.rescheduled_date.format('YYYY-MM-DD');
            }
            if (submitData.status && submitData.status !== 'pending') {
                submitData.rescheduled_date = null;
            }

            if (editingItem) {
                await updateTask(editingItem.id, submitData);
                message.success('Tapşırıq yeniləndi');
            } else {
                await createTask(submitData);
                message.success('Tapşırıq yaradıldı');
            }
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            fetchData();
        } catch (error) {
            console.log(error,'---------------------------')
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleToggleActive = async (id, checked) => {
        try {
            await updateTask(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const openStatusModal = (record) => {
        setEditingItem(record);
        setIsStatusModalOpen(true);
    };

    const handleStatusUpdate = async (values) => {
        try {
            const payload = { status: values.status };
            if (values.status === 'pending' && values.rescheduled_date) {
                payload.rescheduled_date = values.rescheduled_date.format('YYYY-MM-DD');
                payload.pending_note = values.pending_note;
            }
            if (values.status === 'rejected') {
                payload.reject_note = values.reject_note;
            }
            await updateTaskStatus(editingItem.id, payload);
            message.success('Status yeniləndi');
            setIsStatusModalOpen(false);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const handleAcceptTask = async (record) => {
        try {
            await updateTaskStatus(record.id, { status: 'in_progress' });
            message.success('Tapşırıq qəbul edildi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Tapşırıq qəbul edilmədi');
        }
    };

    const openEditModal = (record) => {
        setEditingItem(record);
        form.setFieldsValue({
            ...record,
            status: record.status,
            services: record.services,
            rescheduled_date: record.rescheduled_date ? dayjs(record.rescheduled_date) : undefined
        });
        setIsModalOpen(true);
    };

    const openQuestionnaireModal = (record) => {
        setCurrentTaskForQuestionnaire(record);
        setIsQuestionnaireModalOpen(true);
    };

    const handleViewLocation = (record) => {
        const coords = record.customer_coordinates;
        if (coords && coords.lat && coords.lng) {
            setViewingCoords({ lat: parseFloat(coords.lat), lng: parseFloat(coords.lng) });
            setViewingCustomerName(record.customer_name);
            setIsMapModalOpen(true);
        } else {
            message.info('Bu müştəri üçün ünvan qeyd olunmayıb');
        }
    };

    const openProductModal = (record) => {
        setCurrentTaskForProducts(record);
        setIsProductModalOpen(true);
    };

    const handleNewTask = () => {
        setEditingItem(null);
        form.resetFields();
        form.setFieldsValue({ status: 'todo' });
        setSelectedCoords(null);
        setIsModalOpen(true);
    };

    // Assignee handlers
    const handleOpenAssigneeModal = (record) => {
        setCurrentTaskForAssignee(record);
        setIsAssigneeModalOpen(true);
    };

    const handleAddAssignee = async (taskId, userId) => {
        try {
            await addTaskAssignee(taskId, userId);
            message.success('İcraçı əlavə edildi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'İcraçı əlavə edilmədi');
        }
    };

    const handleJoinTask = async (record) => {
        try {
            await joinTask(record.id);
            message.success('İcraya qoşuldunuz');
            fetchData();
        } catch (error) {
            handleApiError(error, 'İcraya qoşulmaq mümkün olmadı');
        }
    };

    const handleMarkExternalArchived = async (record) => {
        try {
            await markTaskExternalArchived(record.id);
            message.success('Tapşırıq məlumatları arxivləşdirildi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Arxivləşdirmə uğursuz oldu');
        }
    };

    const handleOpenAddressEditor = ({ id, name }) => {
        setAddressEditCustomer({ id, name });
        setIsAddressEditOpen(true);
    };

    return (
        <div>
            <TaskToolbar
                searchText={searchText}
                setSearchText={setSearchText}
                showFilters={showFilters}
                setShowFilters={setShowFilters}
                statusFilter={statusFilter}
                setStatusFilter={setStatusFilter}
                customerFilter={customerFilter}
                setCustomerFilter={setCustomerFilter}
                groupFilter={groupFilter}
                setGroupFilter={setGroupFilter}
                assigneeFilter={assigneeFilter}
                setAssigneeFilter={setAssigneeFilter}
                dateRange={dateRange}
                setDateRange={setDateRange}
                isActiveFilter={isActiveFilter}
                setIsActiveFilter={setIsActiveFilter}
                groups={groups}
                users={users}
                onNewTask={handleNewTask}
                disableCreate={!taskCaps.canCreate}
            />

            <TaskTable
                data={data}
                loading={loading}
                pagination={pagination}
                onChange={handleTableChange}
                tableOrdering={tableOrdering}
                columnIdSearch={columnIdSearch}
                columnRegisterSearch={columnRegisterSearch}
                onColumnIdInputChange={scheduleColumnIdSearch}
                onColumnIdFilterClear={flushColumnIdSearch}
                onColumnIdFilterFlush={flushColumnIdSearch}
                onColumnRegisterInputChange={scheduleColumnRegisterSearch}
                onColumnRegisterFilterClear={flushColumnRegisterSearch}
                onColumnRegisterFilterFlush={flushColumnRegisterSearch}
                services={services}
                onEdit={openEditModal}
                disableEdit={!taskCaps.canEditGeneral}
                disableDelete={!taskCaps.canDelete}
                disableStatus={!taskCaps.canChangeStatus}
                disableQuestionnaire={!taskCaps.canManageSurveys}
                disableProducts={!taskCaps.canManageProducts}
                disableDocuments={!taskCaps.canManageDocuments}
                disableAssigneeManage={!taskCaps.canManageAssignees}
                disableJoinTask={!taskCaps.canJoinTask}
                disableActiveToggle={!taskCaps.canToggleActive}
                onStatusChange={openStatusModal}
                onToggleActive={handleToggleActive}
                onQuestionnaire={openQuestionnaireModal}
                onDelete={handleDelete}
                onAccept={handleAcceptTask}
                onViewLocation={handleViewLocation}
                onViewDetail={(record) => {
                    setSelectedTaskForDetail(record);
                    setIsDetailModalOpen(true);
                }}
                onProductSelect={openProductModal}
                onDocumentAdd={(record) => {
                    setCurrentTaskForDocuments(record);
                    setIsDocumentModalOpen(true);
                }}
                onAddAssignee={handleOpenAssigneeModal}
                onJoinTask={handleJoinTask}
                onMarkExternalArchived={handleMarkExternalArchived}
            />

            <TaskModal
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                onFinish={onFinish}
                form={form}
                editingItem={editingItem}
                groups={groups}
                users={users}
                services={services}
                taskTypes={taskTypes}
                onEditCustomerAddress={handleOpenAddressEditor}
            />

            <QuestionnaireModal
                open={isQuestionnaireModalOpen}
                onCancel={() => setIsQuestionnaireModalOpen(false)}
                task={currentTaskForQuestionnaire}
                assignedServices={
                    currentTaskForQuestionnaire?.services
                        ? currentTaskForQuestionnaire.services.map(serviceId => {
                            const svc = services.find(s => s.id === serviceId);
                            return svc ? { id: svc.id, name: svc.name, icon: svc.icon } : null;
                        }).filter(Boolean)
                        : []
                }
                allColumns={columns}
            />

            <StatusModal
                open={isStatusModalOpen}
                onCancel={() => setIsStatusModalOpen(false)}
                onStatusUpdate={handleStatusUpdate}
                initialStatus={editingItem?.status}
                initialRescheduledDate={editingItem?.rescheduled_date}
                initialPendingNote={editingItem?.pending_note}
            />

            <MapModal
                open={isMapModalOpen}
                onCancel={() => setIsMapModalOpen(false)}
                title={viewingCustomerName}
                coords={viewingCoords}
            />

            <ProductSelectionModal
                open={isProductModalOpen}
                onCancel={() => setIsProductModalOpen(false)}
                task={currentTaskForProducts}
                onSuccess={fetchData}
            />

            <DocumentModal
                open={isDocumentModalOpen}
                onCancel={() => setIsDocumentModalOpen(false)}
                task={currentTaskForDocuments}
                onSuccess={fetchData}
            />

            <TaskDetailModal
                open={isDetailModalOpen}
                onCancel={() => setIsDetailModalOpen(false)}
                task={selectedTaskForDetail}
                services={services}
                onRefresh={fetchData}
                onMarkExternalArchived={handleMarkExternalArchived}
            />

            <AssigneeModal
                open={isAssigneeModalOpen}
                onCancel={() => setIsAssigneeModalOpen(false)}
                task={currentTaskForAssignee}
                users={users}
                onAddAssignee={handleAddAssignee}
            />

            <TaskAddressEditModal
                open={isAddressEditOpen}
                onCancel={() => setIsAddressEditOpen(false)}
                customerId={addressEditCustomer?.id}
                customerName={addressEditCustomer?.name}
                onSaved={() => {
                    fetchData();
                    if (editingItem?.id) {
                        const refreshed = data.find((t) => t.id === editingItem.id);
                        if (refreshed) setEditingItem(refreshed);
                    }
                }}
            />
        </div>
    );
};

export default TaskTab;
