import React, { useEffect, useRef, useState } from 'react';
import { Alert, Button, Card, Descriptions, Progress, Space, Typography } from 'antd';
import { getCustomerImportStatus, startCustomerImport } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';

const { Text } = Typography;

const POLL_MS = 1500;

const CustomerImportTab = () => {
    const [jobId, setJobId] = useState(null);
    const [loading, setLoading] = useState(false);
    const [job, setJob] = useState(null);
    const timerRef = useRef(null);

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

    const percent = job?.total_rows
        ? Math.min(100, Math.round((job.processed_rows / job.total_rows) * 100))
        : 0;

    return (
        <Card title="Bulk Customer Import" bordered>
            <Space direction="vertical" size={16} style={{ width: '100%' }}>
                <Text>
                    Mənbə fayl: <Text code>backend/customers.json</Text>
                </Text>

                <Button type="primary" loading={loading} onClick={handleStart}>
                    Import başlat
                </Button>

                {jobId ? <Text>Job ID: <Text code>{jobId}</Text></Text> : null}

                {job ? (
                    <>
                        <Progress
                            percent={percent}
                            status={job.status === 'failed' ? 'exception' : (job.status === 'done' ? 'success' : 'active')}
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
    );
};

export default CustomerImportTab;

