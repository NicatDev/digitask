import React from 'react';
import { Typography } from 'antd';
import LegalLayout from './LegalLayout';

const { Title, Paragraph } = Typography;

const PrivacyPolicy = () => (
  <LegalLayout title="Privacy Policy">
    <Title level={4}>1. General</Title>
    <Paragraph>
      This policy explains how personal and service-related information is collected and processed
      for users of the DigiTask platform.
    </Paragraph>

    <Title level={4}>2. Information we use</Title>
    <Paragraph>
      The system may process account details (such as name, contact information, and role), operational
      data related to tasks and customers, and technical logs needed for secure and reliable service
      (such as sign-in time and device type), in order to assign tasks, track execution, manage team
      performance, and coordinate business operations.
    </Paragraph>

    <Title level={4}>3. Purpose</Title>
    <Paragraph>
      Data is processed solely for <strong>proper management of tasks and performance</strong>,
      coordination of internal operations, and improvement of the platform.
    </Paragraph>

    <Title level={4}>4. Sale to third parties and advertising</Title>
    <Paragraph>
      Your personal data is <strong>not sold to advertising companies or any third party</strong> and
      is not transferred for commercial marketing purposes. Data may be stored or shared only for the
      purposes described in this policy and where required by law.
    </Paragraph>

    <Title level={4}>5. Retention and security</Title>
    <Paragraph>
      Information is protected using appropriate technical and organisational measures. Retention
      periods are determined according to service needs and legal requirements.
    </Paragraph>

    <Title level={4}>6. Your rights</Title>
    <Paragraph>
      Subject to applicable law, you may submit requests regarding access to, correction of, or
      deletion of your data through your organisation&apos;s administrator.
    </Paragraph>

    <Title level={4}>7. Contact</Title>
    <Paragraph>
      For privacy-related questions, contact your organisation&apos;s DigiTask administrator or your
      designated support channel.
    </Paragraph>
  </LegalLayout>
);

export default PrivacyPolicy;
