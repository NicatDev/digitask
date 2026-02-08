import React, { useEffect, useState } from 'react';
import { Form, message, Grid } from 'antd';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { getTasks, createTask, updateTask, deleteTask, updateTaskStatus, getServices, getColumns, getCustomers, getTaskTypes } from '../../../../axios/api/tasks';
import { getGroups, getUsers } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';
import { useAuth } from '../../../../context/AuthContext';
import { hasPermission, PERMISSIONS } from '../../../../utils/permissions';

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
    const [customers, setCustomers] = useState([]);
    const [groups, setGroups] = useState([]);
    const [users, setUsers] = useState([]);
    const [services, setServices] = useState([]);
    const [columns, setColumns] = useState([]);
    const [taskTypes, setTaskTypes] = useState([]);
    const [pagination, setPagination] = useState({
        current: 1,
        pageSize: 1, // Matching backend page_size=1
        total: 0
    });

    const [loading, setLoading] = useState(false);
    const { user } = useAuth();

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState(null);
    const [customerFilter, setCustomerFilter] = useState(null);
    const [assigneeFilter, setAssigneeFilter] = useState(null);
    const [dateRange, setDateRange] = useState(null);
    const [isActiveFilter, setIsActiveFilter] = useState('all');
    const [showFilters, setShowFilters] = useState(false);

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

    const [form] = Form.useForm();

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
                search: params.search !== undefined ? params.search : debouncedSearchText,
                status: params.status !== undefined ? params.status : statusFilter,
                customer: params.customer !== undefined ? params.customer : customerFilter,
                assigned_to: params.assigned_to !== undefined ? params.assigned_to : assigneeFilter,
                is_active: params.is_active !== undefined ? (params.is_active === 'all' ? undefined : params.is_active) : (isActiveFilter === 'all' ? undefined : isActiveFilter),
                // Date range handling...
            };

            if (dateRange && dateRange[0]) {
                queryParams.date_from = dateRange[0].format('YYYY-MM-DD');
                queryParams.date_to = dateRange[1].format('YYYY-MM-DD');
            }

            const [tasksRes, customersRes, groupsRes, usersRes, servicesRes, columnsRes, taskTypesRes] = await Promise.all([
                getTasks(queryParams),
                getCustomers(),
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
                    total: taskData.count
                }));
            } else {
                setData(taskData); // Fallback for non-paginated
            }

            setCustomers(customersRes.data.results || customersRes.data);
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
            // Reset to page 1 on filter change
            // We need to distinguish between Page Change and Filter Change.
            // Usually best to call fetchData({ page: 1 }) when filters change.
            fetchData({ page: 1 });
        }
    }, [debouncedSearchText, statusFilter, customerFilter, assigneeFilter, isActiveFilter, dateRange]);

    const handleTableChange = (newPagination) => {
        fetchData({ page: newPagination.current });
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
            await updateTaskStatus(editingItem.id, values.status);
            message.success('Status yeniləndi');
            setIsStatusModalOpen(false);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const handleAcceptTask = async (record) => {
        try {
            await updateTaskStatus(record.id, 'in_progress');
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
            services: record.services
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
        setSelectedCoords(null);
        setIsModalOpen(true);
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
                assigneeFilter={assigneeFilter}
                setAssigneeFilter={setAssigneeFilter}
                dateRange={dateRange}
                setDateRange={setDateRange}
                isActiveFilter={isActiveFilter}
                setIsActiveFilter={setIsActiveFilter}
                customers={customers}
                users={users}
                onNewTask={handleNewTask}
                disableCreate={!hasPermission(user, PERMISSIONS.TASK_WRITER)}
            />

            <TaskTable
                data={data}
                loading={loading}
                pagination={pagination}
                onChange={handleTableChange}
                services={services}
                onEdit={openEditModal}
                disableActions={!hasPermission(user, PERMISSIONS.TASK_WRITER)}
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
            />

            <TaskModal
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                onFinish={onFinish}
                form={form}
                editingItem={editingItem}
                customers={customers}
                groups={groups}
                users={users}
                services={services}
                taskTypes={taskTypes}
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
            />
        </div>
    );
};

export default TaskTab;
