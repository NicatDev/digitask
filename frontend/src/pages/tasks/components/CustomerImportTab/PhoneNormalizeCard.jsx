import React, { useState } from 'react';
import { Alert, Button, Card, Collapse, Descriptions, Divider, Popconfirm, Space, Typography } from 'antd';
import { getCustomers, updateCustomer } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';

const { Text } = Typography;

/** 55, 50, 51, 70, 77, 99 ilə başlayan tam 9 rəqəmli nömrəyə başda 0 əlavə edir */
const AZ_MOBILE_PREFIXES = ['55', '50', '51', '70', '77', '99'];

function normalizedAzMobileWithLeadingZero(raw) {
    if (raw == null || raw === '') return null;
    const digits = String(raw).replace(/\D/g, '');
    if (digits.length !== 9) return null;
    const p2 = digits.slice(0, 2);
    if (!AZ_MOBILE_PREFIXES.includes(p2)) return null;
    return `0${digits}`;
}

const digitsOnly = (value) => String(value ?? '').replace(/\D/g, '');

/** Artıq düzgün rəqəmlərdirsə (0 + 9 rəqəm) dəyişiklik lazım deyil */
const needsLeadingZeroFix = (currentValue, normalized) =>
    Boolean(normalized) && digitsOnly(currentValue) !== digitsOnly(normalized);

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

/**
 * Mövcud müştərilərin nömrələrini dəyişən alət (import deyil).
 * Ayrıca və xəbərdarlıqla göstərilir, çünki bu səhifənin qalan hissəsi heç nəyi dəyişmir.
 */
const PhoneNormalizeCard = () => {
    const [loading, setLoading] = useState(false);
    const [log, setLog] = useState([]);
    const [summary, setSummary] = useState(null);

    const append = (line) => setLog((prev) => [...prev, `[${new Date().toISOString()}] ${line}`]);

    const run = async () => {
        setLoading(true);
        setLog([]);
        setSummary(null);
        let updated = 0;
        let errors = 0;
        try {
            append('Müştərilər yüklənir...');
            const customers = await fetchAllCustomers();
            append(`Ümumi müştəri: ${customers.length}`);
            const toPatch = [];
            for (const c of customers) {
                const patch = {};
                const bits = [];
                const nextPhone = normalizedAzMobileWithLeadingZero(c.phone_number);
                if (needsLeadingZeroFix(c.phone_number, nextPhone)) {
                    patch.phone_number = nextPhone;
                    bits.push(`tel: "${c.phone_number}" → "${nextPhone}"`);
                }
                const nextReg = normalizedAzMobileWithLeadingZero(c.register_number);
                if (needsLeadingZeroFix(c.register_number, nextReg)) {
                    patch.register_number = nextReg;
                    bits.push(`qeyd: "${c.register_number}" → "${nextReg}"`);
                }
                if (Object.keys(patch).length > 0) {
                    toPatch.push({ id: c.id, full_name: c.full_name, patch, logLine: bits.join('; ') });
                }
            }
            const notApplicable = customers.length - toPatch.length;
            append(`Dəyişdiriləcək: ${toPatch.length}, şərtə uyğun gəlməyən/artıq eyni: ${notApplicable}`);

            const chunkSize = 8;
            for (let i = 0; i < toPatch.length; i += chunkSize) {
                const chunk = toPatch.slice(i, i + chunkSize);
                await Promise.all(
                    chunk.map(async (row) => {
                        try {
                            await updateCustomer(row.id, row.patch);
                            updated += 1;
                            append(`OK id=${row.id} ${row.full_name || ''}: ${row.logLine}`);
                        } catch (e) {
                            errors += 1;
                            append(`XƏTA id=${row.id}: ${e?.response?.data ? JSON.stringify(e.response.data) : e.message}`);
                        }
                    })
                );
            }
            setSummary({ total: customers.length, notApplicable, updated, errors });
            append(`Bitdi. Yenilənib: ${updated}, xəta: ${errors}.`);
        } catch (e) {
            handleApiError(e, 'Nömrə yenilənməsi alınmadı');
            append(`Ümumi xəta: ${e.message}`);
        } finally {
            setLoading(false);
        }
    };

    return (
        <Collapse
            items={[{
                key: 'phone',
                label: <Text type="danger" strong>Əlavə alət: mövcud müştərilərin nömrələrinə “0” əlavə et (mövcud məlumatı dəyişir)</Text>,
                children: (
                    <Card variant="borderless" styles={{ body: { padding: 0 } }}>
                        <Space orientation="vertical" size={16} style={{ width: '100%' }}>
                            <Alert
                                type="warning"
                                showIcon
                                title="Bu alət importdan ayrıdır və sistemdəki mövcud müştəriləri dəyişir."
                                description={
                                    <>
                                        Həm əlaqə nömrəsi, həm qeydiyyat nömrəsi üçün: yalnız rəqəmlərdən ibarət 9 simvol və prefiksi{' '}
                                        <Text code>{AZ_MOBILE_PREFIXES.join(', ')}</Text> olan dəyərlərin əvvəlinə <Text code>0</Text>{' '}
                                        əlavə olunur (məs. 554264644 → 0554264644). Import hər iki formatı eyni nömrə kimi tanıyır,
                                        ona görə bu alət dublikat yaratmır.
                                    </>
                                }
                            />
                            <Popconfirm
                                title="Bütün müştərilərin nömrələri yoxlanılıb düzəldilsin?"
                                okText="Bəli"
                                cancelText="Xeyr"
                                onConfirm={run}
                            >
                                <Button danger loading={loading}>Bütün müştəriləri yoxla və düzəlt</Button>
                            </Popconfirm>
                            {summary && (
                                <Descriptions size="small" column={2} bordered>
                                    <Descriptions.Item label="Ümumi müştəri">{summary.total}</Descriptions.Item>
                                    <Descriptions.Item label="Uğurla yeniləndi">{summary.updated}</Descriptions.Item>
                                    <Descriptions.Item label="Şərtə uyğun gəlməyən">{summary.notApplicable}</Descriptions.Item>
                                    <Descriptions.Item label="Xəta">{summary.errors}</Descriptions.Item>
                                </Descriptions>
                            )}
                            {log.length > 0 && (
                                <>
                                    <Divider titlePlacement="start">Log</Divider>
                                    <pre style={{
                                        margin: 0, maxHeight: 320, overflow: 'auto', whiteSpace: 'pre-wrap',
                                        background: '#0d1117', color: '#c9d1d9', padding: 12, borderRadius: 6, fontSize: 12,
                                    }}>
                                        {log.join('\n')}
                                    </pre>
                                </>
                            )}
                        </Space>
                    </Card>
                ),
            }]}
        />
    );
};

export default PhoneNormalizeCard;
