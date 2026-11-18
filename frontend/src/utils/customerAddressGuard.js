import { Modal } from 'antd';

export const CUSTOMER_ADDRESS_REQUIRED_CODE = 'customer_address_required';

/** Müştərinin ünvanı var sayılır: xəritədə koordinat (lat + lng) qeyd olunub. */
export const hasCustomerAddress = (task) => {
    const c = task?.customer_coordinates;
    return Boolean(c && c.lat !== undefined && c.lat !== null && c.lat !== '' && c.lng !== undefined && c.lng !== null && c.lng !== '');
};

/** Tapşırıq "done"-a keçirilir və müştərinin ünvanı yoxdur? */
export const isBlockedDoneWithoutAddress = (task, nextStatus) =>
    nextStatus === 'done' && task?.status !== 'done' && !hasCustomerAddress(task);

export const isCustomerAddressRequiredError = (error) =>
    error?.response?.data?.code === CUSTOMER_ADDRESS_REQUIRED_CODE;

export const showCustomerAddressRequiredModal = () =>
    Modal.warning({
        title: 'Müştəri ünvanı əlavə edilməlidir',
        content:
            'Müştəri ünvanını daxil etmədən tapşırığı tamamlamaq mümkün deyil. ' +
            'Əvvəlcə müştəri ünvanını əlavə edin (Ünvan sütunundakı narıncı ikon və ya tapşırığın redaktəsi).',
        okText: 'Anladım',
        closable: true,
        maskClosable: false,
        centered: true,
    });
