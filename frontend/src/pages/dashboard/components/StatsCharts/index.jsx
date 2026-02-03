import React, { useEffect, useState } from 'react';
import { Pie, Column, Bar, Area } from '@ant-design/plots';
import { Card, Statistic, Row, Col, Tabs } from 'antd';
import styles from './style.module.scss';
import { getDashboardStats } from '../../../../axios/api/dashboard';

const StatsCharts = () => {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchStats();
    }, []);

    const fetchStats = async () => {
        try {
            const res = await getDashboardStats();
            setStats(res.data);
        } catch (error) {
            console.error('Stats fetch error', error);
        } finally {
            setLoading(false);
        }
    };

    if (loading || !stats) return <div>Yüklənir...</div>;

    const { tasks, warehouse } = stats;

    // Status Translations
    const STATUS_MAP = {
        'todo': 'Gözləyir',
        'in_progress': 'İcrada',
        'arrived': 'Çatdı',
        'done': 'Tamamlandı',
        'pending': 'Təxirə salındı',
        'rejected': 'Rədd edildi'
    };

    // Data Transformations
    const statusData = tasks.by_status.map(s => ({
        type: STATUS_MAP[s.status] || s.status,
        value: s.count
    }));

    // Fix: type_stats mapping in backend uses .values(name, color), so map correctly
    const fixedTypeData = tasks.by_type.map((t) => ({
        type: t['task_type__name'] || 'Digər',
        value: t.count,
        color: t['task_type__color'] || '#ccc'
    }));

    const userData = tasks.by_user.map(u => ({
        user: u['assigned_to__username'],
        value: u.count
    }));

    const warehouseData = warehouse.movements_last_30_days.map(m => ({
        date: m.movement_type, // Backend currently returns group by type for simplicity, adjust if date needed
        value: m.count
    }));

    const tabItems = [
        {
            key: '1',
            label: 'Tapşırıq Statusları',
            children: (
                <div className={styles.chartCard} style={{ margin: 0, padding: 0, boxShadow: 'none' }}>
                    {/* 
                        Note: The inner chartCard logic in original code had margin:0.
                        Since I reused .chartCard which has padding and shadow, and this is inside a .chartCard (Tabs wrapper),
                        we might not want double padding/shadow.
                        Original code: 
                            Outer div className=chartCard (Tabs)
                            Tabs -> children -> div className=chartCard margin=0
                        This implies double card visual?
                        If I want to be safe, I remove shadow/padding from inner. 
                        Added inline reset for inner wrapper to be safe as per "inside tabs".
                     */}
                    <Pie
                        data={statusData}
                        angleField="value"
                        colorField="type"
                        radius={0.8}
                        label={{ text: 'value', style: { fontWeight: 'bold' } }}
                        legend={{ position: 'bottom' }}
                        height={350} // Increased height for better view in single tab
                        autoFit
                    />
                </div>
            )
        },
        {
            key: '2',
            label: 'Tapşırıq Növləri',
            children: (
                <div className={styles.chartCard} style={{ margin: 0, padding: 0, boxShadow: 'none' }}>
                    <Column
                        data={fixedTypeData}
                        xField="type"
                        yField="value"
                        color={({ type }) => {
                            const item = fixedTypeData.find(d => d.type === type);
                            return item ? item.color : '#1890ff';
                        }}
                        height={350}
                        autoFit
                    />
                </div>
            )
        },
        {
            key: '3',
            label: 'Top 5 İstifadəçi', // Explicit label as requested
            children: (
                <div className={styles.chartCard} style={{ margin: 0, padding: 0, boxShadow: 'none' }}>
                    <Bar
                        data={userData}
                        xField="value"
                        yField="user"
                        height={350}
                        autoFit
                    />
                </div>
            )
        },
        {
            key: '4',
            label: 'Anbar Əməliyyatları',
            children: (
                <div className={styles.chartCard} style={{ margin: 0, padding: 0, boxShadow: 'none' }}>
                    <Column
                        data={warehouseData}
                        xField="date"
                        yField="value"
                        color="#52c41a"
                        height={350}
                        autoFit
                    />
                </div>
            )
        }
    ];

    return (
        <div className={styles.statsContainer}>
            <div className={styles.chartCard}>
                <Row gutter={16}>
                    <Col span={12}>
                        <Statistic title="Ümumi Tapşırıq" value={tasks.total} />
                    </Col>
                    <Col span={12}>
                        <Statistic title="Aktiv Tapşırıq" value={tasks.active} valueStyle={{ color: '#3f8600' }} />
                    </Col>
                </Row>
            </div>

            <div className={styles.chartCard}>
                <Tabs defaultActiveKey="1" items={tabItems} type="card" />
            </div>
        </div>
    );
};

export default StatsCharts;
