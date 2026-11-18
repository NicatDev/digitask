import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Modal, Form, Input, AutoComplete, Button, Spin, Typography, message } from 'antd';
import { AimOutlined, SearchOutlined, EnvironmentOutlined } from '@ant-design/icons';
import { MapContainer, TileLayer, Marker, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import markerIcon from 'leaflet/dist/images/marker-icon.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';
import { getCustomer, updateCustomer } from '../../../../../../axios/api/tasks';
import { handleApiError } from '../../../../../../utils/errorHandler';

const { Text } = Typography;

const DEFAULT_CENTER = [40.4093, 49.8671]; // Bakı
const NOMINATIM = 'https://nominatim.openstreetmap.org';

const pinIcon = L.icon({
    iconUrl: markerIcon,
    shadowUrl: markerShadow,
    iconSize: [25, 41],
    iconAnchor: [12, 41],
});

const searchPlaces = async (query) => {
    const res = await fetch(
        `${NOMINATIM}/search?format=json&q=${encodeURIComponent(query)}&limit=6&countrycodes=az&accept-language=az`
    );
    const data = await res.json();
    return (Array.isArray(data) ? data : []).map((item) => ({
        value: item.display_name,
        label: item.display_name,
        lat: parseFloat(item.lat),
        lng: parseFloat(item.lon),
    }));
};

const reverseGeocode = async ({ lat, lng }) => {
    try {
        const res = await fetch(
            `${NOMINATIM}/reverse?format=json&lat=${lat}&lon=${lng}&zoom=18&accept-language=az`
        );
        const data = await res.json();
        return data?.display_name || '';
    } catch {
        return '';
    }
};

const MapClickHandler = ({ onPick }) => {
    useMapEvents({
        click(e) {
            onPick({ lat: e.latlng.lat, lng: e.latlng.lng });
        },
    });
    return null;
};

/** Yalnız `flyKey` dəyişəndə xəritəni nöqtəyə aparır (klikdə zoom sıçramasın). */
const FlyTo = ({ coords, flyKey }) => {
    const map = useMap();
    useEffect(() => {
        if (coords?.lat && coords?.lng) map.setView([coords.lat, coords.lng], 17);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [flyKey, map]);
    return null;
};

const MapResizer = () => {
    const map = useMap();
    useEffect(() => {
        const timer = setTimeout(() => map.invalidateSize(), 150);
        return () => clearTimeout(timer);
    }, [map]);
    return null;
};

const TaskAddressEditModal = ({ open, onCancel, customerId, customerName, onSaved }) => {
    const [form] = Form.useForm();
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [coords, setCoords] = useState(null);
    const [flyKey, setFlyKey] = useState(0);
    const [searchText, setSearchText] = useState('');
    const [options, setOptions] = useState([]);
    const [searching, setSearching] = useState(false);
    const searchSeq = useRef(0);
    const pickedRef = useRef('');

    const moveTo = (next) => {
        setCoords(next);
        setFlyKey((k) => k + 1);
    };

    useEffect(() => {
        if (!open || !customerId) return;
        setLoading(true);
        setSearchText('');
        setOptions([]);
        getCustomer(customerId)
            .then((res) => {
                const c = res.data;
                form.setFieldsValue({ address: c.address || '' });
                if (c.address_coordinates?.lat && c.address_coordinates?.lng) {
                    moveTo({
                        lat: parseFloat(c.address_coordinates.lat),
                        lng: parseFloat(c.address_coordinates.lng),
                    });
                } else {
                    setCoords(null);
                }
            })
            .catch((e) => handleApiError(e, 'Müştəri məlumatı yüklənmədi'))
            .finally(() => setLoading(false));
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [open, customerId]);

    const runSearch = useCallback(async (query) => {
        const q = (query || '').trim();
        if (q.length < 3) {
            setOptions([]);
            return [];
        }
        const seq = ++searchSeq.current;
        setSearching(true);
        try {
            const found = await searchPlaces(q);
            if (seq === searchSeq.current) setOptions(found);
            return found;
        } catch {
            return [];
        } finally {
            if (seq === searchSeq.current) setSearching(false);
        }
    }, []);

    // Yazdıqca (debounce) təkliflər; seçilmiş nəticənin özü üçün təkrar axtarma
    useEffect(() => {
        if (searchText && searchText === pickedRef.current) return undefined;
        const timer = setTimeout(() => runSearch(searchText), 450);
        return () => clearTimeout(timer);
    }, [searchText, runSearch]);

    const applyPlace = (place) => {
        pickedRef.current = place.value;
        searchSeq.current += 1; // gözləyən axtarış nəticələrini ləğv et
        setSearching(false);
        moveTo({ lat: place.lat, lng: place.lng });
        form.setFieldValue('address', place.value);
        setOptions([]);
    };

    /** Enter / "Tap" düyməsi: ilk nəticəni xəritədə göstər */
    const findOnMap = async (query) => {
        const q = (query ?? searchText).trim();
        if (q.length < 3) {
            message.info('Axtarış üçün ən azı 3 hərf yazın');
            return;
        }
        const found = await runSearch(q);
        if (found.length) {
            applyPlace(found[0]);
        } else {
            message.warning('Ünvan tapılmadı. Başqa sözlə yoxlayın və ya xəritəyə klik edin.');
        }
    };

    const handleMapPick = async (next) => {
        setCoords(next);
        const current = (form.getFieldValue('address') || '').trim();
        if (!current) {
            const label = await reverseGeocode(next);
            if (label) form.setFieldValue('address', label);
        }
    };

    const handleUseMyLocation = () => {
        if (!navigator?.geolocation) {
            message.error('Brauzer lokasiyanı dəstəkləmir');
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (pos) => handleMapPick({ lat: pos.coords.latitude, lng: pos.coords.longitude }).then(() => setFlyKey((k) => k + 1)),
            () => message.error('Lokasiya əldə edilə bilmədi'),
            { enableHighAccuracy: true, timeout: 10000 }
        );
    };

    const handleSave = async () => {
        if (!customerId) return;
        const values = await form.validateFields();
        if (!coords) {
            message.warning('Xəritədə müştərinin yerini seçin (axtarın və ya xəritəyə klik edin)');
            return;
        }
        setSaving(true);
        try {
            await updateCustomer(customerId, {
                address: (values.address || '').trim(),
                address_coordinates: { lat: coords.lat, lng: coords.lng },
            });
            message.success('Müştəri ünvanı yeniləndi');
            onSaved?.();
            onCancel?.();
        } catch (e) {
            handleApiError(e, 'Ünvan yenilənmədi');
        } finally {
            setSaving(false);
        }
    };

    return (
        <Modal
            title={`📍 Müştəri ünvanı: ${customerName || ''}`}
            open={open}
            onCancel={onCancel}
            onOk={handleSave}
            okText="Yadda saxla"
            cancelText="Ləğv et"
            confirmLoading={saving}
            width={820}
            destroyOnClose
        >
            {loading ? (
                <div style={{ textAlign: 'center', padding: 24 }}>
                    <Spin />
                </div>
            ) : (
                <>
                    <AutoComplete
                        style={{ width: '100%', marginBottom: 12 }}
                        options={options}
                        value={searchText}
                        onSearch={setSearchText}
                        onChange={setSearchText}
                        onSelect={(_, option) => applyPlace(option)}
                        notFoundContent={searching ? <Spin size="small" /> : null}
                    >
                        <Input.Search
                            size="large"
                            placeholder="Ünvanı axtarın: küçə, məhəllə, bina..."
                            prefix={<SearchOutlined />}
                            enterButton="Xəritədə tap"
                            loading={searching}
                            onSearch={(v) => findOnMap(v)}
                            allowClear
                        />
                    </AutoComplete>

                    <Form form={form} layout="vertical">
                        <Form.Item
                            name="address"
                            label="Ünvan"
                            rules={[{ required: true, whitespace: true, message: 'Ünvanı daxil edin' }]}
                            style={{ marginBottom: 12 }}
                        >
                            <Input
                                placeholder="Məs: Hövsan qəs., Ə. Əliyev küç. 12, mən. 5"
                                prefix={<EnvironmentOutlined />}
                                suffix={
                                    <Button
                                        type="link"
                                        size="small"
                                        style={{ padding: 0, height: 'auto' }}
                                        onClick={() => findOnMap(form.getFieldValue('address'))}
                                    >
                                        Xəritədə göstər
                                    </Button>
                                }
                            />
                        </Form.Item>
                    </Form>

                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 8, flexWrap: 'wrap' }}>
                        <Text type="secondary" style={{ fontSize: 12 }}>
                            Yeri dəqiqləşdirmək üçün xəritəyə klik edin.
                            {coords ? ` Seçilib: ${coords.lat.toFixed(5)}, ${coords.lng.toFixed(5)}` : ' Hələ yer seçilməyib.'}
                        </Text>
                        <Button icon={<AimOutlined />} onClick={handleUseMyLocation}>
                            Mənim lokasiyam
                        </Button>
                    </div>

                    <div style={{ height: 380, width: '100%', borderRadius: 8, overflow: 'hidden' }}>
                        <MapContainer
                            center={coords ? [coords.lat, coords.lng] : DEFAULT_CENTER}
                            zoom={coords ? 17 : 12}
                            style={{ height: '100%', width: '100%' }}
                        >
                            <TileLayer
                                attribution="&copy; OpenStreetMap contributors"
                                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                            />
                            <MapResizer />
                            <MapClickHandler onPick={handleMapPick} />
                            <FlyTo coords={coords} flyKey={flyKey} />
                            {coords ? (
                                <Marker
                                    position={[coords.lat, coords.lng]}
                                    icon={pinIcon}
                                    draggable
                                    eventHandlers={{
                                        dragend: (e) => {
                                            const p = e.target.getLatLng();
                                            setCoords({ lat: p.lat, lng: p.lng });
                                        },
                                    }}
                                />
                            ) : null}
                        </MapContainer>
                    </div>
                </>
            )}
        </Modal>
    );
};

export default TaskAddressEditModal;
