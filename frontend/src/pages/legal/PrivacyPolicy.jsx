import React from 'react';
import { Typography } from 'antd';
import LegalLayout from './LegalLayout';

const { Title, Paragraph } = Typography;

const PrivacyPolicy = () => (
  <LegalLayout title="Privacy Policy" updated="26 November 2026">
    <Title level={4}>1. Who we are</Title>
    <Paragraph>
      DigiTask is a task and field-work management service operated by
      <strong> Diginet Limited Liability Company</strong> (kv. 31, 36A Ziya Bunyadov str., Baku,
      AZ1069, Azerbaijan). This policy applies to the DigiTask web platform and the DigiTask mobile
      applications for iOS and Android.
    </Paragraph>

    <Title level={4}>2. Accounts</Title>
    <Paragraph>
      User accounts are created and managed by the organisation&apos;s administrator. The app does
      not offer public self-registration.
    </Paragraph>

    <Title level={4}>3. Information we process</Title>
    <Paragraph>
      <ul>
        <li><strong>Account details:</strong> name, user name, contact details, role, group and profile photo.</li>
        <li><strong>Precise location:</strong> see section 4.</li>
        <li><strong>Work content:</strong> tasks, task statuses and history, surveys, comments, chat and support messages.</li>
        <li><strong>Photos and files</strong> that you choose to attach (camera, photo library or files).</li>
        <li><strong>Customer records</strong> entered for task execution, such as name, phone number and address.</li>
        <li><strong>Device and technical data:</strong> push notification token, device model and operating system version, sign-in and activity logs, crash and error reports.</li>
      </ul>
    </Paragraph>

    <Title level={4}>4. Location data</Title>
    <Paragraph>
      With your permission, the mobile app collects your precise location while you are signed in,
      <strong> including when the app is running in the background</strong>. Your location is sent
      to the DigiTask server and shown to authorised users of your organisation (for example
      dispatchers and administrators) on a live map, in order to coordinate field work, assign tasks
      and verify task execution. Location is also used to set a customer&apos;s address on the map.
    </Paragraph>
    <Paragraph>
      Location collection is intended to stop when you sign out. You can also turn off location
      access at any time in your device settings; some features will then not work. Location data is
      not used for advertising.
    </Paragraph>

    <Title level={4}>5. Purpose</Title>
    <Paragraph>
      Data is processed to provide the service: managing tasks and performance, coordinating field
      work, sending notifications, keeping the service secure and fixing errors.
    </Paragraph>

    <Title level={4}>6. Service providers</Title>
    <Paragraph>
      Your data is <strong>not sold</strong> and is not used for advertising or tracking across other
      companies&apos; apps or websites. We use the following providers to run the service:
      <ul>
        <li><strong>Google Firebase</strong> (push notifications and crash reporting).</li>
        <li><strong>Apple Push Notification service</strong> (delivery of notifications on iOS).</li>
        <li><strong>OpenStreetMap</strong> services (map tiles and address search; the address text or map point you search for is sent to these services).</li>
      </ul>
      Data may also be disclosed where required by law.
    </Paragraph>

    <Title level={4}>7. Retention and security</Title>
    <Paragraph>
      Data is transmitted over encrypted connections and access is limited by user role. It is kept
      for as long as needed to provide the service to your organisation and to meet legal
      requirements.
    </Paragraph>

    <Title level={4}>8. Your rights</Title>
    <Paragraph>
      Subject to applicable law, you may request access to, correction of, or deletion of your data,
      or ask for your account to be closed, through your organisation&apos;s administrator or by
      contacting us.
    </Paragraph>

    <Title level={4}>9. Contact</Title>
    <Paragraph>
      Diginet Limited Liability Company, kv. 31, 36A Ziya Bunyadov str., Baku, AZ1069, Azerbaijan.
      Phone: +994 12 310 60 68.
    </Paragraph>
  </LegalLayout>
);

export default PrivacyPolicy;
