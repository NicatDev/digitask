import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, Button, Card, Progress, Space, Typography, Upload } from 'antd';
import {
    FileExcelOutlined, FileTextOutlined, InboxOutlined, QuestionCircleOutlined, ReloadOutlined,
} from '@ant-design/icons';
import {
    getActiveCustomerImport, getCustomerImport, getCustomerImports, uploadCustomerImport,
} from '../../../../axios/api/tasks';
import ActiveBatchPanel from './ActiveBatchPanel';
import BatchDetailDrawer from './BatchDetailDrawer';
import HistoryTable from './HistoryTable';
import ImportRulesModal from './ImportRulesModal';
import PhoneNormalizeCard from './PhoneNormalizeCard';
import RollbackModal from './RollbackModal';
import { RUNNING, downloadFile, showError } from './utils';
import styles from './style.module.scss';

const { Title, Text, Paragraph } = Typography;
const POLL_MS = 1500;
const MAX_SIZE = 10 * 1024 * 1024;

const userError = (detail) => showError({ response: { data: { detail } } });

const CustomerImportTab = () => {
    const [rulesOpen, setRulesOpen] = useState(false);
    const [current, setCurrent] = useState(null);
    const [uploading, setUploading] = useState(false);
    const [uploadPct, setUploadPct] = useState(0);
    const [history, setHistory] = useState([]);
    const [historyLoading, setHistoryLoading] = useState(false);
    const [historyPage, setHistoryPage] = useState({ current: 1, pageSize: 20, total: 0 });
    const [detail, setDetail] = useState(null);
    const [detailRefresh, setDetailRefresh] = useState(0);
    const [rollbackBatch, setRollbackBatch] = useState(null);
    const pollRef = useRef(null);
    const lastStatusRef = useRef(null);
    const pageSizeRef = useRef(20);

    const loadHistory = useCallback(async (page = 1, pageSize = pageSizeRef.current) => {
        pageSizeRef.current = pageSize;
        setHistoryLoading(true);
        try {
            const res = await getCustomerImports({ page, page_size: pageSize });
            setHistory(res.data.results || []);
            setHistoryPage({ current: page, pageSize, total: res.data.count || 0 });
        } catch (e) {
            await showError(e, 'Tarixçə yüklənmədi');
        } finally {
            setHistoryLoading(false);
        }
    }, []);

    const applyBatch = useCallback((b) => {
        setCurrent(b);
        if (!b) return;
        // Detallar açıqdırsa onu da yenilə
        setDetail((d) => (d && d.id === b.id ? b : d));
        if (lastStatusRef.current !== b.status) {
            lastStatusRef.current = b.status;
            loadHistory(1);
            setDetailRefresh((k) => k + 1);
        }
    }, [loadHistory]);

    // Səhifə açılanda: yarımçıq və ya təsdiq gözləyən import varmı?
    useEffect(() => {
        (async () => {
            try {
                const res = await getActiveCustomerImport();
                if (res.data) applyBatch(res.data);
            } catch (e) {
                await showError(e, 'Hazırkı import yoxlanmadı');
            }
        })();
        loadHistory(1);
    }, [applyBatch, loadHistory]);

    // İşləyən proses varsa vəziyyəti izləyirik
    const currentId = current?.id;
    const currentStatus = current?.status;
    useEffect(() => {
        if (pollRef.current) clearInterval(pollRef.current);
        if (!currentId || !RUNNING.includes(currentStatus)) return undefined;
        let failures = 0;
        pollRef.current = setInterval(async () => {
            try {
                const res = await getCustomerImport(currentId);
                failures = 0;
                applyBatch(res.data);
            } catch {
                failures += 1;
                // Şəbəkə qısa müddət kəsilsə də proses serverdə davam edir — izləməyə davam edirik
                if (failures === 5) userError('Serverlə əlaqə kəsilib. Proses serverdə davam edir — əlaqə bərpa olunanda nəticə görünəcək.');
            }
        }, POLL_MS);
        return () => clearInterval(pollRef.current);
    }, [currentId, currentStatus, applyBatch]);

    const blocked = current && ['validating', 'importing', 'rolling_back', 'interrupted'].includes(current.status);

    const beforeUpload = async (file) => {
        const name = file.name.toLowerCase();
        if (!name.endsWith('.xlsx') && !name.endsWith('.json')) {
            userError('Yalnız Excel (.xlsx) və JSON (.json) faylları yükləmək olar. Köhnə .xls və ya .csv faylını Excel-də “.xlsx” kimi saxlayın.');
            return Upload.LIST_IGNORE;
        }
        if (file.size > MAX_SIZE) {
            userError('Fayl çox böyükdür (maksimum 10 MB). Faylı hissələrə bölüb yükləyin.');
            return Upload.LIST_IGNORE;
        }
        if (file.size === 0) {
            userError('Fayl boşdur.');
            return Upload.LIST_IGNORE;
        }
        setUploading(true);
        setUploadPct(0);
        try {
            const res = await uploadCustomerImport(file, (ev) => {
                if (ev.total) setUploadPct(Math.round((ev.loaded / ev.total) * 100));
            });
            lastStatusRef.current = null;
            applyBatch(res.data);
        } catch (e) {
            await showError(e, 'Fayl yüklənmədi');
        } finally {
            setUploading(false);
        }
        return Upload.LIST_IGNORE;
    };

    const openDetails = async (b) => {
        setDetail(b);
        try {
            const res = await getCustomerImport(b.id);
            setDetail(res.data);
        } catch (e) {
            await showError(e, 'Import tapılmadı');
        }
    };

    const onBatchChanged = (b) => {
        lastStatusRef.current = null;
        applyBatch(b);
    };

    return (
        <div className={styles.page}>
            <div className={styles.header}>
                <div>
                    <Title level={3}>Müştəri importu</Title>
                    <Text type="secondary">
                        Excel və ya JSON faylından <b>yeni</b> müştəriləri əlavə edin. Sistemdə olan müştərilər dəyişdirilmir və silinmir.
                    </Text>
                </div>
                <Button icon={<QuestionCircleOutlined />} onClick={() => setRulesOpen(true)}>Qaydalara bax</Button>
            </div>

            <div className={styles.steps}>
                <Card title={<span className={styles.stepTitle}><span className={styles.stepNum}>1</span>Şablonu endirin</span>}>
                    <Paragraph type="secondary">
                        Şablonu doldurun: hər müştəri bir sətir. Ulduzlu sütunlar məcburidir, qeydiyyat nömrəsi və ya telefondan ən azı biri lazımdır.
                    </Paragraph>
                    <Space wrap>
                        <Button type="primary" ghost icon={<FileExcelOutlined />}
                                onClick={() => downloadFile('template/', undefined, 'musteri-import-sablonu.xlsx')}>
                            Excel şablonu
                        </Button>
                        <Button icon={<FileTextOutlined />}
                                onClick={() => downloadFile('sample-json/', undefined, 'musteri-import-numunesi.json')}>
                            JSON nümunəsi
                        </Button>
                    </Space>
                </Card>

                <Card title={<span className={styles.stepTitle}><span className={styles.stepNum}>2</span>Faylı yükləyin</span>}>
                    {blocked ? (
                        <Alert
                            type="info"
                            showIcon
                            title={current.status === 'interrupted'
                                ? 'Əvvəlki import yarımçıq qalıb. Yeni fayl yükləmək üçün əvvəlcə onu “Davam et” və ya “Geri qaytar” edin.'
                                : 'Hazırda bir əməliyyat gedir. Bitəndən sonra yeni fayl yükləyə bilərsiniz.'}
                        />
                    ) : (
                        <Upload.Dragger
                            accept=".xlsx,.json"
                            multiple={false}
                            showUploadList={false}
                            beforeUpload={beforeUpload}
                            disabled={uploading}
                        >
                            <p className="ant-upload-drag-icon"><InboxOutlined /></p>
                            <p className="ant-upload-text">Faylı bura sürüşdürün və ya klikləyib seçin</p>
                            <p className="ant-upload-hint">
                                Excel (.xlsx) və ya JSON (.json), maksimum 10 MB. Yükləyəndə heç nə yaradılmır — əvvəlcə nəticəni görəcəksiniz.
                            </p>
                            {uploading && <Progress percent={uploadPct} size="small" style={{ maxWidth: 320, margin: '0 auto' }} />}
                        </Upload.Dragger>
                    )}
                    {current?.status === 'preview' && (
                        <Text type="secondary" style={{ display: 'block', marginTop: 8, fontSize: 12 }}>
                            Yeni fayl yükləsəniz, təsdiq gözləyən hazırkı import avtomatik ləğv olunacaq.
                        </Text>
                    )}
                </Card>
            </div>

            <ActiveBatchPanel
                batch={current}
                onChange={onBatchChanged}
                onOpenDetails={openDetails}
                onRollback={setRollbackBatch}
                onDismiss={() => { setCurrent(null); lastStatusRef.current = null; }}
            />

            <Card
                title="Importların tarixçəsi"
                extra={(
                    <Button size="small" icon={<ReloadOutlined />}
                            onClick={() => loadHistory(historyPage.current, historyPage.pageSize)}>
                        Yenilə
                    </Button>
                )}
            >
                <HistoryTable
                    data={history}
                    loading={historyLoading}
                    pagination={historyPage}
                    onChange={(p) => loadHistory(p.current, p.pageSize)}
                    onOpen={openDetails}
                    onRollback={setRollbackBatch}
                />
            </Card>

            <PhoneNormalizeCard />

            <ImportRulesModal open={rulesOpen} onClose={() => setRulesOpen(false)} />
            {detail && <BatchDetailDrawer batch={detail} onClose={() => setDetail(null)} refreshKey={detailRefresh} />}
            {rollbackBatch && (
                <RollbackModal batch={rollbackBatch} onClose={() => setRollbackBatch(null)} onDone={onBatchChanged} />
            )}
        </div>
    );
};

export default CustomerImportTab;
