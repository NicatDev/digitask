import React, { useEffect, useState } from 'react';
import { Modal, Input, List, Button, message } from 'antd';
import { BarcodeOutlined, SwapOutlined } from '@ant-design/icons';
import { getSerialItems } from '../../../../axios/api/warehouse/index';

const SerialListModal = ({ open, onClose, product, onExport }) => {
    const [items, setItems] = useState([]);
    const [loading, setLoading] = useState(false);
    const [search, setSearch] = useState('');
    const [pagination, setPagination] = useState({ current: 1, pageSize: 50, total: 0 });

    const fetchItems = async (page = 1, searchText = '') => {
        if (!product) return;
        setLoading(true);
        try {
            const params = { product: product.id, page, page_size: 50 };
            if (searchText) params.search = searchText;
            const res = await getSerialItems(params);
            const result = res.data;
            setItems(result.results || result || []);
            setPagination(p => ({ ...p, current: page, total: result.count || 0 }));
        } catch (e) {
            message.error('Serial nömrələr yüklənmədi');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (open && product) {
            setSearch('');
            fetchItems(1, '');
        }
    }, [open, product?.id]);

    // Debounced search
    useEffect(() => {
        if (open && product) {
            const timer = setTimeout(() => fetchItems(1, search), 300);
            return () => clearTimeout(timer);
        }
    }, [search]);

    return (
        <Modal
            title={`Serial Nömrələr: ${product?.name || ''}`}
            open={open} onCancel={onClose} footer={null} width={650} destroyOnClose
        >
            <Input.Search
                placeholder="Serial nömrə axtar..."
                value={search} onChange={e => setSearch(e.target.value)}
                style={{ marginBottom: 16 }} allowClear
            />
            <div style={{ maxHeight: '60vh', overflowY: 'auto' }}>
                <List
                    loading={loading}
                    dataSource={items}
                    locale={{ emptyText: 'Serial nömrə yoxdur' }}
                    pagination={{
                        current: pagination.current,
                        pageSize: pagination.pageSize,
                        total: pagination.total,
                        onChange: (page) => fetchItems(page, search),
                        size: 'small',
                    }}
                    renderItem={item => (
                        <List.Item actions={[
                            <Button size="small" icon={<SwapOutlined />} onClick={() => {
                                onExport(item);
                                onClose();
                            }}>Export/Transfer</Button>
                        ]}>
                            <List.Item.Meta
                                avatar={<BarcodeOutlined style={{ fontSize: 20, color: '#1890ff' }} />}
                                title={item.serial_number}
                                description={`Anbar: ${item.warehouse_name} | ${new Date(item.created_at).toLocaleDateString('az-AZ')}`}
                            />
                        </List.Item>
                    )}
                />
            </div>
        </Modal>
    );
};

export default SerialListModal;
