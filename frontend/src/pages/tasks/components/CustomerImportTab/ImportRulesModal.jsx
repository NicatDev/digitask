import React from 'react';
import { Button, Collapse, Modal, Typography } from 'antd';
import styles from './style.module.scss';

const { Paragraph, Text } = Typography;

const items = [
    {
        key: 'steps',
        label: '1. Necə işləyir?',
        children: (
            <ol className={styles.rulesList}>
                <li><b>Şablonu endirin</b> — Excel şablonu və ya JSON nümunəsi.</li>
                <li><b>Müştəriləri doldurun</b> — hər müştəri bir sətir.</li>
                <li><b>Faylı yükləyin.</b> Sistem faylı yoxlayır, amma <b>hələ heç nə yaratmır</b>.</li>
                <li><b>Nəticəyə baxın:</b> neçəsi yeni, neçəsi artıq var, neçəsi problemli.</li>
                <li><b>“Təsdiqlə” düyməsini basın</b> — yalnız bundan sonra yeni müştərilər yaradılır.</li>
            </ol>
        ),
    },
    {
        key: 'fields',
        label: '2. Hansı sütunlar var, hansılar məcburidir?',
        children: (
            <ul className={styles.rulesList}>
                <li><b>Ad Soyad</b> — məcburidir.</li>
                <li><b>Region</b> — məcburidir.</li>
                <li><b>Qeydiyyat nömrəsi</b> və ya <b>Telefon</b> — ikisindən ən azı biri mütləq olmalıdır.</li>
                <li><b>Avadanlıq, Optik qutu, Ünvan</b> — istəyə bağlıdır.</li>
                <li><b>Enlik və Uzunluq</b> (xəritədə yer) — istəyə bağlıdır, amma yazırsınızsa ikisi birlikdə olmalıdır.
                    Məsələn: <Text code>40.4093</Text> və <Text code>49.8671</Text>.</li>
                <li>Passport şəkli kimi fayllar importla əlavə olunmur — onları sonra müştərinin kartından əlavə edin.</li>
            </ul>
        ),
    },
    {
        key: 'phones',
        label: '3. Nömrələri necə yazmalı?',
        children: (
            <ul className={styles.rulesList}>
                <li>İstənilən formada yaza bilərsiniz — hamısı eyni nömrə sayılır:
                    <Text code>0554264644</Text> <Text code>554264644</Text> <Text code>+994 55 426 46 44</Text></li>
                <li>Bir müştərinin bir neçə telefonu varsa, vergüllə ayırın: <Text code>0554264644, 0501234567</Text></li>
                <li>Qeydiyyat nömrəsi xanasına yalnız <b>bir</b> nömrə yazın.</li>
                <li><Text code>NULL</Text>, <Text code>0</Text>, <Text code>-</Text> kimi dəyərlər boş sayılır.</li>
                <li>Excel nömrəni <Text code>9.94E+11</Text> kimi göstərirsə, o nömrə korlanıb — düzgün nömrəni yenidən yazın.
                    Şablonda nömrə sütunları bunun qarşısını almaq üçün “mətn” formatındadır.</li>
            </ul>
        ),
    },
    {
        key: 'existing',
        label: '4. Müştərinin artıq olduğunu sistem necə bilir?',
        children: (
            <>
                <Paragraph>
                    Fayldakı <b>qeydiyyat nömrəsi</b> və ya <b>telefon</b> sistemdəki hər hansı müştərinin qeydiyyat nömrəsi
                    və ya telefonu ilə eynidirsə, bu müştəri <b>artıq var</b> sayılır.
                </Paragraph>
                <ul className={styles.rulesList}>
                    <li>Belə müştərilər <b>yaradılmır və dəyişdirilmir</b>. Sistemdəki məlumat olduğu kimi qalır.</li>
                    <li>Silinmiş (deaktiv) müştərilər də yoxlanılır — onlar da yenidən yaradılmır.</li>
                    <li>Tarixçədə “Müqayisə et” ilə fayldakı təklifi sistemdəki müştəri ilə yan-yana görə bilərsiniz.</li>
                    <li>Eyni ad tək başına “eyni müştəri” sayılmır (eyni adlı fərqli insanlar ola bilər), amma xəbərdarlıq göstərilir.</li>
                </ul>
            </>
        ),
    },
    {
        key: 'file-dupes',
        label: '5. Faylda eyni müştəri iki dəfə yazılıbsa?',
        children: (
            <ul className={styles.rulesList}>
                <li>Sətirlər tam eynidirsə — müştəri <b>bir dəfə</b> yaradılır, digəri “faylda təkrar” kimi göstərilir.</li>
                <li>Nömrə eynidir, amma digər məlumatlar fərqlidirsə (məs. başqa ad) — hansının düzgün olduğu bilinmir,
                    ona görə <b>heç biri yaradılmır</b> və problemli kimi göstərilir.</li>
                <li>Ailə üzvləri eyni telefonu paylaşırsa, onları əl ilə əlavə edin.</li>
            </ul>
        ),
    },
    {
        key: 'refs',
        label: '6. Region, avadanlıq və optik qutu necə tapılır?',
        children: (
            <ul className={styles.rulesList}>
                <li>Sistem yazdığınız adı mövcud adlarla müqayisə edir. Böyük-kiçik hərf, <Text code>ə/e</Text>,
                    <Text code>ı/i</Text>, boşluq və tire fərq etmir: “suraxani” = “Suraxanı”.</li>
                <li>Kiçik hərf səhvləri də tanınır (60%-dən çox oxşarlıq): “Suraxany” → “Suraxanı”. Belə hallarda
                    nəticədə “… kimi tanındı” qeydi görünür — yoxlayın.</li>
                <li>Adında fərqli rəqəm olanlar heç vaxt qarışdırılmır: “SW021” ilə “SW022” fərqli sayılır.</li>
                <li>Oxşar ad tapılmasa — <b>yenisi yaradılır</b>. Önbaxışda hansıların yaradılacağı göstərilir.</li>
                <li>Ad sistemdə <b>deaktiv</b> edilmiş birinə uyğun gəlirsə, sətir problemli sayılır.</li>
            </ul>
        ),
    },
    {
        key: 'problems',
        label: '7. Problemli sətirlərlə nə etməli?',
        children: (
            <ul className={styles.rulesList}>
                <li>Problemli sətirlər yaradılmır. Hər birinin yanında səbəbi yazılır.</li>
                <li>“Excel kimi endir” ilə onları yükləyin, səbəbə baxıb düzəldin və faylı yenidən yükləyin.</li>
                <li>Artıq yaradılmış müştərilər ikinci yükləmədə yenidən yaradılmır — narahat olmayın.</li>
            </ul>
        ),
    },
    {
        key: 'safety',
        label: '8. Proses yarımçıq qalsa və ya səhv etsəm?',
        children: (
            <ul className={styles.rulesList}>
                <li>Müştərilər kiçik hissələrlə yaradılır. Bağlantı kəsilsə və ya server yenidən başlasa,
                    yarımçıq hissə tamamilə ləğv olunur — yarımçıq məlumat qalmır.</li>
                <li>Belə halda <b>“Davam et”</b> qalanları yaradır, <b>“Geri qaytar”</b> isə hamısını ləğv edir.</li>
                <li><b>“Geri qaytar”</b> yalnız <b>ən son</b> import üçün mümkündür və yalnız həmin importun yaratdığı
                    müştəriləri silir (sonradan əlavə edilmiş şəkillər də daxil). Mövcud müştərilərə toxunmur.</li>
                <li>Bu importla yaradılmış müştəriyə artıq tapşırıq verilibsə, geri qaytarmaq olmur — tapşırıq məlumatı itməsin deyə.</li>
                <li>Yaradılma zamanı səhifəni bağlasanız da proses davam edir.</li>
            </ul>
        ),
    },
];

const ImportRulesModal = ({ open, onClose }) => (
    <Modal
        title="Müştəri importu — qaydalar"
        open={open}
        onCancel={onClose}
        width={760}
        footer={<Button type="primary" onClick={onClose}>Anladım</Button>}
    >
        <Paragraph type="secondary">
            Bu səhifə yalnız <b>yeni</b> müştəriləri əlavə edir. Sistemdə olan müştərilər heç vaxt dəyişdirilmir və silinmir.
        </Paragraph>
        <Collapse items={items} defaultActiveKey={['steps']} />
    </Modal>
);

export default ImportRulesModal;
