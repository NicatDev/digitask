import React, { useEffect, useMemo, useState } from 'react';
import { Table, DatePicker, Button, Row, Col, Space, Tag, Progress, Segmented, Tooltip, Modal } from 'antd';
import { LeftOutlined, RightOutlined, ReloadOutlined, ExclamationCircleOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import styles from './style.module.scss';
import { getUserPerformance } from '../../axios/api/performance';
import { Typography } from 'antd';

const { Title } = Typography;

const AZ_MONTHS = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avqust', 'sentyabr', 'oktyabr', 'noyabr', 'dekabr',
];
const AZ_MONTHS_TITLE = AZ_MONTHS.map((m) => m.charAt(0).toUpperCase() + m.slice(1));

const PERIOD_OPTIONS = [
    { label: 'Ümumi', value: 'all' },
    { label: 'Aylıq', value: 'month' },
    { label: 'Həftəlik', value: 'week' },
    { label: 'Günlük', value: 'day' },
];

const TODAY_LABEL = { day: 'Bu gün', week: 'Bu həftə', month: 'Bu ay' };

/** Həftə bazar ertəsindən başlayır (backend ilə eyni qayda) */
const startOfWeekMon = (d) => d.subtract((d.day() + 6) % 7, 'day').startOf('day');

const getRange = (period, anchor) => {
    if (period === 'day') return [anchor.startOf('day'), anchor.startOf('day')];
    if (period === 'week') {
        const s = startOfWeekMon(anchor);
        return [s, s.add(6, 'day')];
    }
    return [anchor.startOf('month'), anchor.endOf('month')];
};

const fmtDay = (d) => `${d.date()} ${AZ_MONTHS[d.month()]} ${d.year()}`;

const formatRangeLabel = (period, anchor) => {
    const [s, e] = getRange(period, anchor);
    if (period === 'day') return fmtDay(s);
    if (period === 'month') return `${AZ_MONTHS_TITLE[s.month()]} ${s.year()}`;
    if (s.year() !== e.year()) return `${fmtDay(s)} – ${fmtDay(e)}`;
    if (s.month() !== e.month()) {
        return `${s.date()} ${AZ_MONTHS[s.month()]} – ${e.date()} ${AZ_MONTHS[e.month()]} ${e.year()}`;
    }
    return `${s.date()} – ${e.date()} ${AZ_MONTHS[e.month()]} ${e.year()}`;
};

const isCurrentPeriod = (period, anchor) => {
    const [s] = getRange(period, anchor);
    const [ts] = getRange(period, dayjs());
    return s.isSame(ts, 'day');
};

const PerformancePage = () => {
    const [loading, setLoading] = useState(false);
    const [data, setData] = useState([]);
    const [period, setPeriod] = useState('month');
    const [anchor, setAnchor] = useState(() => dayjs());
    const [infoOpen, setInfoOpen] = useState(false);
    const isAll = period === 'all';

    useEffect(() => {
        fetchData();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [period, anchor]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const res = await getUserPerformance(
                isAll ? { period } : { period, date: anchor.format('YYYY-MM-DD') }
            );
            setData(res.data);
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const shift = (dir) => setAnchor((a) => a.add(dir, period));
    const isCurrent = isAll || isCurrentPeriod(period, anchor);
    const rangeLabel = isAll ? 'Bütün dövr' : formatRangeLabel(period, anchor);

    const summary = useMemo(() => {
        const completed = data.reduce((acc, r) => acc + (r.stats?.completed || 0), 0);
        const active = data.reduce((acc, r) => acc + (r.stats?.active || 0), 0);
        const activeInPeriod = data.reduce((acc, r) => acc + (r.stats?.active_in_period || 0), 0);
        const total = completed + active;
        return {
            completed,
            active,
            activeInPeriod,
            efficiency: total > 0 ? Math.round((completed / total) * 1000) / 10 : 0,
        };
    }, [data]);

    const columns = [
        {
            title: 'İstifadəçi',
            dataIndex: ['user', 'full_name'],
            key: 'user',
            render: (text, record) => (
                <div style={{ fontWeight: 500 }}>{text || record.user.username}</div>
            )
        },
        {
            title: 'Ümumi',
            dataIndex: ['stats', 'total'],
            key: 'total',
            sorter: (a, b) => a.stats.total - b.stats.total,
        },
        {
            title: 'Tamamlanmış',
            dataIndex: ['stats', 'completed'],
            key: 'completed',
            sorter: (a, b) => a.stats.completed - b.stats.completed,
            render: (val) => <Tag color="green">{val}</Tag>
        },
        {
            title: (
                <Tooltip title="Seçilmiş dövrdə yaradılmış və hələ də aktiv olan tapşırıqlar">
                    Dövr üzrə aktiv
                </Tooltip>
            ),
            dataIndex: ['stats', 'active_in_period'],
            key: 'active_in_period',
            sorter: (a, b) => (a.stats.active_in_period || 0) - (b.stats.active_in_period || 0),
            render: (val) => <Tag color="geekblue">{val ?? 0}</Tag>
        },
        {
            title: (
                <Tooltip title="Tarixdən asılı olmayaraq hazırda aktiv olan bütün tapşırıqlar">
                    Ümumi aktiv
                </Tooltip>
            ),
            dataIndex: ['stats', 'active'],
            key: 'active',
            sorter: (a, b) => a.stats.active - b.stats.active,
            render: (val) => <Tag color="blue">{val}</Tag>
        },
        {
            title: 'Effektivlik',
            dataIndex: ['stats', 'efficiency'],
            key: 'efficiency',
            sorter: (a, b) => a.stats.efficiency - b.stats.efficiency,
            render: (val) => (
                <Progress percent={val} size="small" status={val === 100 ? "success" : "active"} />
            )
        },
        {
            title: 'Top Növlər',
            key: 'breakdown',
            width: 300,
            render: (_, record) => (
                <Space wrap>
                    {record.breakdown.types.slice(0, 3).map((t, index) => (
                        <Tag key={index} color="cyan">
                            {t.task_type__name || 'Təyin olunmayıb'}: <strong>{t.count}</strong>
                        </Tag>
                    ))}
                    {record.breakdown.types.length === 0 && <span style={{ color: '#999', fontSize: '12px' }}>-</span>}
                </Space>
            )
        }
    ];

    const expandedRowRender = (record) => {
        return (
            <div style={{ padding: '20px', background: '#fafafa', borderRadius: '8px' }}>
                <Row gutter={[16, 16]}>
                    <Col xs={24} lg={12}>
                        <h4 style={{ marginBottom: 16 }}>Tapşırıq Növləri (Detallı)</h4>
                        <Space wrap>
                             {record.breakdown.types.length > 0 ? (
                                record.breakdown.types.map((t, index) => (
                                    <Tag key={index} color="cyan" style={{ marginBottom: 8, padding: '4px 10px' }}>
                                        {t.task_type__name || 'Təyin olunmayıb'}: <span style={{ fontWeight: 600 }}>{t.count}</span>
                                    </Tag>
                                ))
                            ) : (
                                <span style={{ color: '#999' }}>Məlumat yoxdur</span>
                            )}
                        </Space>
                    </Col>
                    <Col xs={24} lg={12}>
                        <h4 style={{ marginBottom: 16 }}>Servislər (Detallı)</h4>
                        <Space wrap>
                            {record.breakdown.services.length > 0 ? (
                                record.breakdown.services.map((s, index) => (
                                    <Tag key={index} color="purple" style={{ marginBottom: 8, padding: '4px 10px' }}>
                                        {s.services__name || 'Təyin olunmayıb'}: <span style={{ fontWeight: 600 }}>{s.count}</span>
                                    </Tag>
                                ))
                            ) : (
                                <span style={{ color: '#999' }}>Məlumat yoxdur</span>
                            )}
                        </Space>
                    </Col>
                </Row>
            </div>
        );
    };

    return (
        <div className={styles.performancePage}>
            <Title level={2} className={styles.pageTitle}>
                İşçi Performansı
                <Tooltip title="Necə hesablanır?">
                    <ExclamationCircleOutlined
                        className={styles.infoIcon}
                        onClick={() => setInfoOpen(true)}
                    />
                </Tooltip>
            </Title>

            <Modal
                title="Performans necə hesablanır?"
                open={infoOpen}
                onCancel={() => setInfoOpen(false)}
                footer={<Button type="primary" onClick={() => setInfoOpen(false)}>Bağla</Button>}
            >
                <div className={styles.infoBody}>
                    <p><strong>Filtrlər:</strong></p>
                    <ul>
                        <li><strong>Ümumi</strong> — bütün dövr, tarix məhdudiyyəti yoxdur.</li>
                        <li><strong>Aylıq</strong> — seçilmiş ayın 1-dən sonuna qədər (cari ay üçün: ayın 1-dən bu günə qədər).</li>
                        <li><strong>Həftəlik</strong> — bazar ertəsindən bazar gününə qədər.</li>
                        <li><strong>Günlük</strong> — seçilmiş bir gün.</li>
                    </ul>
                    <p>Bütün tarixlər Bakı vaxtı (UTC+4) ilə hesablanır.</p>

                    <p><strong>Tamamlanmış</strong> — seçilmiş dövrdə statusu həqiqətən “Tamamlandı”ya keçirilmiş tapşırıqlar.
                        Tarix tapşırığın tamamlandığı an götürülür, sonradan edilən redaktələr (başlıq, qeyd, qrup və s.) tarixi dəyişmir.
                        Tamamlanandan sonra statusu geri qaytarılmış və ya silinmiş tapşırıqlar sayılmır.
                        “Ümumi” filtrində hazırda tamamlanmış bütün tapşırıqlar sayılır.</p>

                    <p><strong>Dövr üzrə aktiv</strong> — seçilmiş dövrdə yaradılmış və hazırda hələ də “Gözləyir” və ya “İcrada” olan tapşırıqlar.</p>

                    <p><strong>Ümumi aktiv</strong> — tarixdən asılı olmayaraq hazırda “Gözləyir” və ya “İcrada” olan bütün tapşırıqlar.</p>

                    <p><strong>Ümumi</strong> sütunu = Tamamlanmış + Ümumi aktiv.</p>

                    <p><strong>Effektivlik</strong> = Tamamlanmış ÷ (Tamamlanmış + Ümumi aktiv) × 100%.</p>

                    <p><strong>Qeydlər:</strong></p>
                    <ul>
                        <li>Tapşırığın bir neçə icraçısı varsa, hər icraçıya ayrıca sayılır.</li>
                        <li>“Təxirə salındı” və “Rədd edildi” statuslu tapşırıqlar heç bir sayğaca daxil deyil.</li>
                        <li>Silinmiş (deaktiv) tapşırıqlar sayılmır.</li>
                    </ul>
                </div>
            </Modal>

            <div className={styles.periodBar}>
                <Segmented
                    options={PERIOD_OPTIONS}
                    value={period}
                    onChange={(v) => setPeriod(v)}
                    className={styles.periodSegmented}
                />

                <div className={styles.dateNav}>
                    {!isAll && (<>
                    <Tooltip title="Əvvəlki">
                        <Button icon={<LeftOutlined />} onClick={() => shift(-1)} />
                    </Tooltip>
                    <DatePicker
                        picker={period === 'month' ? 'month' : 'date'}
                        value={anchor}
                        allowClear={false}
                        inputReadOnly
                        format={() => rangeLabel}
                        onChange={(d) => d && setAnchor(d)}
                        disabledDate={(d) => d && d.isAfter(dayjs().endOf('day'))}
                        className={styles.datePicker}
                    />
                    <Tooltip title="Növbəti">
                        <Button
                            icon={<RightOutlined />}
                            onClick={() => shift(1)}
                            disabled={isCurrent}
                        />
                    </Tooltip>
                    <Button
                        type={isCurrent ? 'default' : 'primary'}
                        ghost={!isCurrent}
                        disabled={isCurrent}
                        onClick={() => setAnchor(dayjs())}
                    >
                        {TODAY_LABEL[period]}
                    </Button>
                    </>)}
                    <Tooltip title="Yenilə">
                        <Button icon={<ReloadOutlined />} onClick={fetchData} loading={loading} />
                    </Tooltip>
                </div>
            </div>

            <Row gutter={[12, 12]} className={styles.summaryRow}>
                <Col xs={12} md={6}>
                    <div className={`${styles.summaryCard} ${styles.summaryDone}`}>
                        <span className={styles.summaryLabel}>Tamamlanmış</span>
                        <span className={styles.summaryValue}>{summary.completed}</span>
                    </div>
                </Col>
                <Col xs={12} md={6}>
                    <div className={`${styles.summaryCard} ${styles.summaryPeriodActive}`}>
                        <span className={styles.summaryLabel}>Dövr üzrə aktiv</span>
                        <span className={styles.summaryValue}>{summary.activeInPeriod}</span>
                    </div>
                </Col>
                <Col xs={12} md={6}>
                    <div className={`${styles.summaryCard} ${styles.summaryActive}`}>
                        <span className={styles.summaryLabel}>Ümumi aktiv</span>
                        <span className={styles.summaryValue}>{summary.active}</span>
                    </div>
                </Col>
                <Col xs={12} md={6}>
                    <div className={`${styles.summaryCard} ${styles.summaryEff}`}>
                        <span className={styles.summaryLabel}>Ümumi effektivlik</span>
                        <span className={styles.summaryValue}>{summary.efficiency}%</span>
                    </div>
                </Col>
            </Row>

            <div className={styles.tableScroll}>
                <Table
                    loading={loading}
                    columns={columns}
                    dataSource={data}
                    rowKey={record => record.user.id}
                    expandable={{ expandedRowRender }}
                    pagination={false}
                    scroll={{ x: 'max-content' }}
                />
            </div>
        </div>
    );
};

export default PerformancePage;
