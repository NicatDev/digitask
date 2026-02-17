import React, { useState } from 'react';
import { Modal, Select, Button, message } from 'antd';

const { Option } = Select;

const AssigneeModal = ({ open, onCancel, task, users, onAddAssignee }) => {
    const [selectedUserId, setSelectedUserId] = useState(null);
    const [loading, setLoading] = useState(false);

    if (!task) return null;

    const currentAssigneeIds = task.assigned_to || [];
    const availableUsers = users.filter(u => u.is_active && !currentAssigneeIds.includes(u.id));

    const handleAdd = async () => {
        if (!selectedUserId) {
            message.warning('İcraçı seçin');
            return;
        }
        setLoading(true);
        try {
            await onAddAssignee(task.id, selectedUserId);
            setSelectedUserId(null);
            onCancel();
        } catch (error) {
            // Error handled by parent
        } finally {
            setLoading(false);
        }
    };

    return (
        <Modal
            title="İcraçı əlavə et"
            open={open}
            onCancel={() => { setSelectedUserId(null); onCancel(); }}
            footer={[
                <Button key="cancel" onClick={() => { setSelectedUserId(null); onCancel(); }}>
                    Ləğv et
                </Button>,
                <Button key="add" type="primary" loading={loading} onClick={handleAdd}>
                    Əlavə et
                </Button>
            ]}
            width={500}
            destroyOnClose
        >
            <div style={{ marginBottom: 8 }}>
                <strong>Cari icraçılar: </strong>
                {task.assigned_to_names && task.assigned_to_names.length > 0
                    ? task.assigned_to_names.join(', ')
                    : 'Yoxdur'}
            </div>
            <Select
                showSearch
                optionFilterProp="children"
                placeholder="İcraçı axtarın..."
                style={{ width: '100%' }}
                value={selectedUserId}
                onChange={setSelectedUserId}
                filterOption={(input, option) =>
                    option.children.toLowerCase().includes(input.toLowerCase())
                }
            >
                {availableUsers.map(u => (
                    <Option key={u.id} value={u.id}>
                        {u.first_name} {u.last_name}
                    </Option>
                ))}
            </Select>
        </Modal>
    );
};

export default AssigneeModal;
