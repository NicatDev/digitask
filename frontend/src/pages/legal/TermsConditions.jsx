import React from 'react';
import { Typography } from 'antd';
import LegalLayout from './LegalLayout';

const { Title, Paragraph } = Typography;

const TermsConditions = () => (
  <LegalLayout title="Terms of Use">
    <Title level={4}>1. Description of the service</Title>
    <Paragraph>
      DigiTask is an internal business tool intended for task management, team collaboration, and
      monitoring of operational processes. Use of the platform is subject to your organisation&apos;s
      rules and these terms.
    </Paragraph>

    <Title level={4}>2. Account and responsibility</Title>
    <Paragraph>
      You are responsible for keeping your login credentials confidential. Actions performed through
      your account are attributed to you or to the roles assigned by your organisation.
    </Paragraph>

    <Title level={4}>3. Use of data</Title>
    <Paragraph>
      Information you submit to the platform is processed for the purpose of{' '}
      <strong>managing tasks and performance</strong>. This data is not sold to advertising or
      marketing companies and is not transferred to third parties for commercial purposes (except
      where required by law).
    </Paragraph>

    <Title level={4}>4. Acceptable use</Title>
    <Paragraph>
      You must use the platform only for lawful purposes and in line with your organisation&apos;s
      internal policies. Any activity that could harm the system or compromise security is
      prohibited.
    </Paragraph>

    <Title level={4}>5. Availability and changes</Title>
    <Paragraph>
      The service is provided &quot;as is&quot;. Features and terms may be updated to meet organisational
      needs; material changes may be communicated through your organisation.
    </Paragraph>

    <Title level={4}>6. Contact</Title>
    <Paragraph>
      For questions about these terms, contact your organisation&apos;s administrator.
    </Paragraph>
  </LegalLayout>
);

export default TermsConditions;
