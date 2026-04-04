import React from 'react';
import { Typography, Layout } from 'antd';
import { Link } from 'react-router-dom';
import styles from './LegalLayout.module.scss';

const { Title, Paragraph } = Typography;
const { Content } = Layout;

const LegalLayout = ({ title, children }) => (
  <Layout className={styles.legalRoot}>
    <Content className={styles.legalContent}>
      <Link to="/login" className={styles.backLink}>
        ← Back to sign in
      </Link>
      <Title level={2}>{title}</Title>
      <div className={styles.legalBody}>{children}</div>
      <Paragraph type="secondary" className={styles.footerNote}>
        Last updated: {new Date().toLocaleDateString('en-GB')}
      </Paragraph>
    </Content>
  </Layout>
);

export default LegalLayout;
