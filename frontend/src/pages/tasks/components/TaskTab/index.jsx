import React, { useEffect, useState } from 'react';
import { Form, message, Grid } from 'antd';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { getTasks, createTask, updateTask, deleteTask, updateTaskStatus, getServices, getColumns, getCustomers } from '../../../../axios/api/tasks';
import { getGroups, getUsers } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';

// Components
import TaskModal from './TaskModal';
import QuestionnaireModal from './QuestionnaireModal/index';
import TaskToolbar from './components/TaskToolbar';
import TaskTable from './components/TaskTable';
import StatusModal from './components/StatusModal';
import MapModal from './components/MapModal';

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
    const [loading, setLoading] = useState(false);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState(null);
    const [customerFilter, setCustomerFilter] = useState(null);
    const [isActiveFilter, setIsActiveFilter] = useState('all'); // 'all'=all, true=active, false=inactive
    const [showFilters, setShowFilters] = useState(false);

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isStatusModalOpen, setIsStatusModalOpen] = useState(false);
    const [isQuestionnaireModalOpen, setIsQuestionnaireModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [currentTaskForQuestionnaire, setCurrentTaskForQuestionnaire] = useState(null);

    // Viewing Location MAP (customer's address)
    const [isMapModalOpen, setIsMapModalOpen] = useState(false);
    const [viewingCoords, setViewingCoords] = useState(null);
    const [viewingCustomerName, setViewingCustomerName] = useState('');

    const [form] = Form.useForm();
    // statusForm removed, StatusModal handles its own form or passes value.
    // Actually our StatusModal component uses its own form internally now.

    // Debounce Search
    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [tasksRes, customersRes, groupsRes, usersRes, servicesRes, columnsRes] = await Promise.all([
                getTasks(),
                getCustomers(),
                getGroups(),
                getUsers(),
                getServices(),
                getColumns()
            ]);
            setData(tasksRes.data.results || tasksRes.data);
            setCustomers(customersRes.data.results || customersRes.data);
            setGroups(groupsRes.data.results || groupsRes.data);
            setUsers(usersRes.data.results || usersRes.data);
            setServices(servicesRes.data.results || servicesRes.data);
            setColumns(columnsRes.data.results || columnsRes.data);
        } catch (error) {
            console.error(error);
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (isActive) {
            fetchData();
        }
    }, [isActive]);

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

    const getFilteredData = () => {
        return data.filter(item => {
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch = item.title.toLowerCase().includes(lowerSearch) ||
                (item.customer_name && item.customer_name.toLowerCase().includes(lowerSearch));

            const matchesStatus = statusFilter ? item.status === statusFilter : true;
            const matchesCustomer = customerFilter ? item.customer === customerFilter : true;
            const matchesActive = isActiveFilter !== 'all' ? item.is_active === isActiveFilter : true;
            return matchesSearch && matchesStatus && matchesCustomer && matchesActive;
        });
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
                isActiveFilter={isActiveFilter}
                setIsActiveFilter={setIsActiveFilter}
                customers={customers}
                onNewTask={handleNewTask}
            />

            <TaskTable
                data={getFilteredData()}
                loading={loading}
                services={services}
                onEdit={openEditModal}
                onStatusChange={openStatusModal}
                onToggleActive={handleToggleActive}
                onQuestionnaire={openQuestionnaireModal}
                onDelete={handleDelete}
                onAccept={handleAcceptTask}
                onViewLocation={handleViewLocation}
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
        </div>
    );
};

export default TaskTab;
