import React, { useEffect, useRef, useState } from 'react';
import { Alert, Button, Card, Descriptions, Divider, Progress, Space, Typography } from 'antd';
import { getCustomerImportStatus, startCustomerImport, getCustomers, updateCustomer } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';

const { Text } = Typography;

const POLL_MS = 1500;

/** 55, 50, 51, 70, 77, 99 ilə başlayan tam 9 rəqəmli nömrəyə başda 0 əlavə edir */
const AZ_MOBILE_PREFIXES = ['55', '50', '51', '70', '77', '99'];

/** Telefon və ya qeydiyyat nömrəsi üçün eyni qayda */
function normalizedAzMobileWithLeadingZero(raw) {
    if (raw == null || raw === '') return null;
    const digits = String(raw).replace(/\D/g, '');
    if (digits.length !== 9) return null;
    const p2 = digits.slice(0, 2);
    if (!AZ_MOBILE_PREFIXES.includes(p2)) return null;
    return `0${digits}`;
}

function digitsOnly(value) {
    return String(value ?? '').replace(/\D/g, '');
}

/** Artıq düzgün rəqəmlərdirsə (0 + 9 rəqəm) dəyişiklik lazım deyil */
function needsLeadingZeroFix(currentValue, normalized) {
    if (!normalized) return false;
    return digitsOnly(currentValue) !== digitsOnly(normalized);
}

async function fetchAllCustomers() {
    const all = [];
    let page = 1;
    const pageSize = 100;
    for (;;) {
        const res = await getCustomers({ page, page_size: pageSize });
        const results = res.data?.results ?? [];
        const count = res.data?.count ?? 0;
        all.push(...results);
        if (results.length === 0 || all.length >= count) break;
        page += 1;
    }
    return all;
}

const CustomerImportTab = () => {
    const [jobId, setJobId] = useState(null);
    const [loading, setLoading] = useState(false);
    const [job, setJob] = useState(null);
    const timerRef = useRef(null);

    const [phoneFixLoading, setPhoneFixLoading] = useState(false);
    const [phoneFixLog, setPhoneFixLog] = useState([]);
    const [phoneFixSummary, setPhoneFixSummary] = useState(null);

    const stopPolling = () => {
        if (timerRef.current) {
            clearInterval(timerRef.current);
            timerRef.current = null;
        }
    };

    const fetchStatus = async (id) => {
        try {
            const res = await getCustomerImportStatus(id);
            const current = res.data;
            setJob(current);
            if (current.status === 'done' || current.status === 'failed') {
                stopPolling();
            }
        } catch (e) {
            stopPolling();
            handleApiError(e, 'Import status yoxlanmadı');
        }
    };

    useEffect(() => () => stopPolling(), []);

    const appendPhoneLog = (line) => {
        const ts = new Date().toISOString();
        setPhoneFixLog((prev) => [...prev, `[${ts}] ${line}`]);
    };

    const handleStart = async () => {
        setLoading(true);
        try {
            const res = await startCustomerImport();
            const id = res.data?.job_id;
            if (!id) return;
            setJobId(id);
            await fetchStatus(id);
            stopPolling();
            timerRef.current = setInterval(() => fetchStatus(id), POLL_MS);
        } catch (e) {
            handleApiError(e, 'Import başladılmadı');
        } finally {
            setLoading(false);
        }
    };

    const handleNormalizePhones = async () => {
        setPhoneFixLoading(true);
        setPhoneFixLog([]);
        setPhoneFixSummary(null);
        let updated = 0;
        let errors = 0;

        try {
            appendPhoneLog('Müştərilər yüklənir...');
            const customers = await fetchAllCustomers();
            appendPhoneLog(`Ümumi müştəri: ${customers.length}`);

            const toPatch = [];
            for (const c of customers) {
                const patch = {};
                const logBits = [];

                const nextPhone = normalizedAzMobileWithLeadingZero(c.phone_number);
                if (needsLeadingZeroFix(c.phone_number, nextPhone)) {
                    patch.phone_number = nextPhone;
                    logBits.push(`tel: "${c.phone_number}" → "${nextPhone}"`);
                }

                const nextReg = normalizedAzMobileWithLeadingZero(c.register_number);
                if (needsLeadingZeroFix(c.register_number, nextReg)) {
                    patch.register_number = nextReg;
                    logBits.push(`qeyd: "${c.register_number}" → "${nextReg}"`);
                }

                if (Object.keys(patch).length > 0) {
                    toPatch.push({
                        id: c.id,
                        full_name: c.full_name,
                        patch,
                        logLine: logBits.join('; '),
                    });
                }
            }

            const notApplicable = customers.length - toPatch.length;
            appendPhoneLog(`Dəyişdiriləcək: ${toPatch.length}, şərtə uyğun gəlməyən/artıq eyni: ${notApplicable}`);

            const chunkSize = 8;
            for (let i = 0; i < toPatch.length; i += chunkSize) {
                const chunk = toPatch.slice(i, i + chunkSize);
                await Promise.all(
                    chunk.map(async (row) => {
                        try {
                            await updateCustomer(row.id, row.patch);
                            updated += 1;
                            appendPhoneLog(`OK id=${row.id} ${row.full_name || ''}: ${row.logLine}`);
                        } catch (e) {
                            errors += 1;
                            appendPhoneLog(`XƏTA id=${row.id}: ${e?.response?.data ? JSON.stringify(e.response.data) : e.message}`);
                        }
                    })
                );
            }

            setPhoneFixSummary({
                total: customers.length,
                notApplicable,
                updated,
                errors,
            });
            appendPhoneLog(`Bitdi. Yenilənib: ${updated}, xəta: ${errors}.`);
        } catch (e) {
            handleApiError(e, 'Nömrə yenilənməsi alınmadı');
            appendPhoneLog(`Ümumi xəta: ${e.message}`);
        } finally {
            setPhoneFixLoading(false);
        }
    };

    const percent = job?.total_rows
        ? Math.min(100, Math.round((job.processed_rows / job.total_rows) * 100))
        : 0;

    return (
        <Space direction="vertical" size={24} style={{ width: '100%' }}>
            <Card title="Bulk Customer Import" bordered>
                <Space direction="vertical" size={16} style={{ width: '100%' }}>
                    <Text>
                        Mənbə fayl: <Text code>backend/customers.json</Text>
                    </Text>

                    <Button type="primary" loading={loading} onClick={handleStart}>
                        Import başlat
                    </Button>

                    {jobId ? (
                        <Text>
                            Job ID: <Text code>{jobId}</Text>
                        </Text>
                    ) : null}

                    {job ? (
                        <>
                            <Progress
                                percent={percent}
                                status={
                                    job.status === 'failed'
                                        ? 'exception'
                                        : job.status === 'done'
                                          ? 'success'
                                          : 'active'
                                }
                            />

                            <Descriptions size="small" column={2} bordered>
                                <Descriptions.Item label="Status">{job.status}</Descriptions.Item>
                                <Descriptions.Item label="Ümumi sətir">{job.total_rows}</Descriptions.Item>
                                <Descriptions.Item label="Processed">{job.processed_rows}</Descriptions.Item>
                                <Descriptions.Item label="Created">{job.created_count}</Descriptions.Item>
                                <Descriptions.Item label="Skipped">{job.skipped_count}</Descriptions.Item>
                                <Descriptions.Item label="Errors">{job.error_count}</Descriptions.Item>
                                <Descriptions.Item label="Duration (ms)">{job.duration_ms}</Descriptions.Item>
                                <Descriptions.Item label="Finished">{job.finished_at || '-'}</Descriptions.Item>
                            </Descriptions>

                            {Array.isArray(job.sample_errors) && job.sample_errors.length > 0 ? (
                                <Alert
                                    type="warning"
                                    showIcon
                                    message="Sample errors"
                                    description={
                                        <pre style={{ margin: 0, whiteSpace: 'pre-wrap' }}>
                                            {JSON.stringify(job.sample_errors, null, 2)}
                                        </pre>
                                    }
                                />
                            ) : null}
                        </>
                    ) : null}
                </Space>
            </Card>

            <Card title="Telefon və qeydiyyat nömrəsi (0 prefiksi)" bordered>
                <Space direction="vertical" size={16} style={{ width: '100%' }}>
                    <Text type="secondary">
                        Həm <Text strong>əlaqə nömrəsi</Text>, həm <Text strong>qeydiyyat nömrəsi</Text> üçün: yalnız
                        rəqəmlərdən ibarət <Text strong>9 simvol</Text> və prefiks{' '}
                        <Text code>{AZ_MOBILE_PREFIXES.join(', ')}</Text> olan dəyərlərin əvvəlinə <Text code>0</Text>{' '}
                        əlavə olunur (məs. 554264644 → 0554264644). Digər formatlar toxunulmur.
                    </Text>
                    <Button type="primary" loading={phoneFixLoading} onClick={handleNormalizePhones}>
                        Bütün müştəriləri yoxla və düzəlt
                    </Button>

                    {phoneFixSummary ? (
                        <Descriptions size="small" column={2} bordered>
                            <Descriptions.Item label="Ümumi müştəri">{phoneFixSummary.total}</Descriptions.Item>
                            <Descriptions.Item label="Uğurla yeniləndi">{phoneFixSummary.updated}</Descriptions.Item>
                            <Descriptions.Item label="Şərtə uyğun gəlməyən">{phoneFixSummary.notApplicable}</Descriptions.Item>
                            <Descriptions.Item label="Xəta">{phoneFixSummary.errors}</Descriptions.Item>
                        </Descriptions>
                    ) : null}

                    {phoneFixLog.length > 0 ? (
                        <>
                            <Divider orientation="left">Log</Divider>
                            <pre
                                style={{
                                    margin: 0,
                                    maxHeight: 320,
                                    overflow: 'auto',
                                    whiteSpace: 'pre-wrap',
                                    background: '#0d1117',
                                    color: '#c9d1d9',
                                    padding: 12,
                                    borderRadius: 6,
                                    fontSize: 12,
                                }}
                            >
                                {phoneFixLog.join('\n')}
                            </pre>
                        </>
                    ) : null}
                </Space>
            </Card>
        </Space>
    );
};

export default CustomerImportTab;
