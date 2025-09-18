#!/bin/bash
# This script creates the directory structure and files for the STX Ecosystem Explorer dApp.

echo "🚀 Starting frontend setup..."

# Create the directory structure
mkdir -p frontend/public frontend/src
echo "-> Created directory structure."

# Create frontend/package.json
cat << 'EON' > frontend/package.json
{
  "name": "stx-ecosystem-explorer-dapp",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@aptos-labs/ts-sdk": "^1.9.0",
    "@aptos-labs/wallet-adapter-react": "^3.0.0",
    "antd": "^5.13.2",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "typescript": "^5.0.0"
  }
}
EON
echo "-> Created package.json."

# Create frontend/public/index.html
cat << 'EON' > frontend/public/index.html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="STX Ecosystem Explorer on Aptos" />
    <title>STX Ecosystem Explorer</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EON
echo "-> Created public/index.html."

# Create frontend/src/App.tsx
cat << 'EON' > frontend/src/App.tsx
import React, { useState, useEffect } from 'react';
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { useWallet, InputTransactionData } from "@aptos-labs/wallet-adapter-react";
import { Button, Card, Form, Input, Select, message, Spin, Typography, Space, Tag, Divider, Modal } from 'antd';
import { PlusOutlined, ReloadOutlined, WalletOutlined, GlobalOutlined, InfoCircleOutlined } from '@ant-design/icons';
import './App.css';

const { Title, Text, Paragraph } = Typography;
const { TextArea } = Input;
const { Option } = Select;

const CONTRACT_ADDRESS = "0x6f4289da6b563639c29b45f3cb2d0206e6e6d30d37525b3e90bd417fde20961c";

interface Project {
  id: number;
  name: string;
  description: string;
  url: string;
  category: string;
  submitted_by: string;
}

interface ProjectFormData {
  name: string;
  description: string;
  url: string;
  category: string;
}

const aptosConfig = new AptosConfig({ network: Network.DEVNET });
const aptos = new Aptos(aptosConfig);

const App: React.FC = () => {
  const { account, connected, connect, disconnect, signAndSubmitTransaction } = useWallet();
  const [projects, setProjects] = useState<Project[]>([]);
  const [projectCount, setProjectCount] = useState<number>(0);
  const [loading, setLoading] = useState<boolean>(true);
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [isInitialized, setIsInitialized] = useState<boolean>(false);
  const [form] = Form.useForm();

  const loadProjects = async () => {
    try {
      setLoading(true);
      const checkInitPayload = { function: `${CONTRACT_ADDRESS}::explorer::is_initialized` };
      const initStatus = await aptos.view({ payload: checkInitPayload });
      setIsInitialized(initStatus[0] as boolean);

      if (initStatus[0]) {
        const countPayload = { function: `${CONTRACT_ADDRESS}::explorer::get_project_count` };
        const countResult = await aptos.view({ payload: countPayload });
        const count = Number(countResult[0]);
        setProjectCount(count);

        if (count > 0) {
          const projectsPayload = { function: `${CONTRACT_ADDRESS}::explorer::get_all_projects` };
          const projectsResult = await aptos.view({ payload: projectsPayload });
          setProjects(projectsResult[0] as Project[] || []);
        } else {
          setProjects([]);
        }
      } else {
        setProjects([]);
        setProjectCount(0);
      }
    } catch (error: any) {
      console.error("Error loading projects:", error);
      message.error("Failed to load projects. Is the contract deployed and initialized?");
      setProjects([]);
      setProjectCount(0);
    } finally {
      setLoading(false);
    }
  };
  
  const handleSubmit = async (values: ProjectFormData) => {
    if (!connected || !account) {
      message.error("Please connect your wallet first");
      return;
    }
    try {
      setSubmitting(true);
      const transaction: InputTransactionData = {
        data: {
          function: `${CONTRACT_ADDRESS}::explorer::add_project`,
          functionArguments: [values.name, values.description, values.url, values.category],
        },
      };
      const response = await signAndSubmitTransaction(transaction);
      await aptos.waitForTransaction({ transactionHash: response.hash });
      message.success("Project added successfully!");
      form.resetFields();
      await loadProjects();
    } catch (error) {
      console.error("Error submitting project:", error);
      message.error("Failed to add project. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  const initializeContract = async () => {
    if (!connected || !account) {
      message.error("Please connect your wallet first");
      return;
    }
    Modal.confirm({
      title: 'Initialize Contract?',
      icon: <InfoCircleOutlined />,
      content: 'This is a one-time setup action required for the contract to work. This should only be done by the contract owner.',
      okText: 'Initialize',
      cancelText: 'Cancel',
      onOk: async () => {
        try {
          setLoading(true);
          const transaction: InputTransactionData = {
            data: {
              function: `${CONTRACT_ADDRESS}::explorer::initialize_explorer`,
              functionArguments: [],
            },
          };
          const response = await signAndSubmitTransaction(transaction);
          await aptos.waitForTransaction({ transactionHash: response.hash });
          message.success("Contract initialized successfully!");
          await loadProjects();
        } catch (error) {
          console.error("Error initializing contract:", error);
          message.error("Failed to initialize contract.");
        } finally {
          setLoading(false);
        }
      },
    });
  };

  useEffect(() => {
    loadProjects();
  }, []);

  return (
    <div className="app">
      <div className="app-header">
        <Title level={1} className="app-title">🚀 STX Ecosystem Explorer</Title>
        <Text className="app-subtitle">Discover and submit projects on the Aptos network</Text>
        <div className="stats-container">
          <Card className="stat-card"><Title level={2}>{projectCount}</Title><Text>Total Projects</Text></Card>
        </div>
      </div>
      <div className="app-content">
        <Card className="wallet-card">
          {!connected ? (
            <div className="wallet-connect">
              <WalletOutlined style={{ fontSize: '48px', color: '#667eea', marginBottom: '16px' }} />
              <Title level={3}>Connect Your Wallet</Title>
              <Paragraph>Connect to start submitting projects</Paragraph>
              <Button type="primary" size="large" onClick={() => connect("Petra" as any)} icon={<WalletOutlined />}>Connect Petra Wallet</Button>
            </div>
          ) : (
            <div className="wallet-connected">
              <Space direction="vertical" align="center">
                <div className="connection-status"><div className="status-dot" /><Text>Connected: {account?.address.slice(0, 6)}...{account?.address.slice(-4)}</Text></div>
                <Button onClick={disconnect} type="default">Disconnect</Button>
              </Space>
            </div>
          )}
        </Card>
        <div className="main-grid">
          <Card title={<Space><PlusOutlined />Submit New Project</Space>} className="form-card">
            <Form form={form} layout="vertical" onFinish={handleSubmit} disabled={!connected}>
              <Form.Item name="name" label="Project Name" rules={[{ required: true, message: 'Please enter project name' }]}>
                <Input placeholder="e.g. Amazing DeFi Protocol" />
              </Form.Item>
              <Form.Item name="description" label="Description" rules={[{ required: true, message: 'Please enter description' }]}>
                <TextArea rows={3} placeholder="Brief description of your project..." />
              </Form.Item>
              <Form.Item name="url" label="Project URL" rules={[{ required: true, message: 'Please enter project URL' }, { type: 'url', message: 'Please enter a valid URL' }]}>
                <Input placeholder="https://your-project.com" />
              </Form.Item>
              <Form.Item name="category" label="Category" rules={[{ required: true, message: 'Please select a category' }]}>
                <Select placeholder="Select a category">
                  <Option value="DeFi">DeFi</Option><Option value="NFT">NFT</Option><Option value="Gaming">Gaming</Option>
                  <Option value="Infrastructure">Infrastructure</Option><Option value="Social">Social</Option><Option value="Other">Other</Option>
                </Select>
              </Form.Item>
              <Form.Item>
                <Button type="primary" htmlType="submit" loading={submitting} disabled={!connected} block>
                  {submitting ? 'Adding Project...' : 'Add Project'}
                </Button>
              </Form.Item>
            </Form>
          </Card>
          <Card title="Quick Actions" className="actions-card">
            <Space direction="vertical" style={{ width: '100%' }}>
              <Button icon={<ReloadOutlined />} onClick={loadProjects} loading={loading} block>Refresh Projects</Button>
              {connected && !isInitialized && (
                <Button type="dashed" onClick={initializeContract} loading={loading} block>Initialize Contract (Owner Only)</Button>
              )}
            </Space>
            <Divider />
            <div className="contract-info">
              <Title level={5}>Contract Info</Title>
              <Text className="contract-address" copyable={{ text: CONTRACT_ADDRESS }}>Address: {CONTRACT_ADDRESS.slice(0, 10)}...{CONTRACT_ADDRESS.slice(-8)}</Text>
              <br /><Text type="secondary">Network: Aptos Devnet</Text>
            </div>
          </Card>
        </div>
        <Card title={<Space><GlobalOutlined />Featured Projects ({projects.length})</Space>} className="projects-card">
          {loading ? (
            <div className="loading-container"><Spin size="large" /><Text>Loading projects...</Text></div>
          ) : projects.length === 0 ? (
            <div className="empty-state">
              <Title level={4}>{isInitialized ? "No projects yet" : "Contract not initialized"}</Title>
              <Paragraph>{isInitialized ? "Be the first to submit a project to the STX Ecosystem!" : "The contract owner must initialize the contract before projects can be added."}</Paragraph>
            </div>
          ) : (
            <div className="projects-grid">
              {projects.map((project) => (
                <Card key={project.id} className="project-card" actions={[<Button type="link" href={project.url} target="_blank" rel="noopener noreferrer" icon={<GlobalOutlined />}>Visit Project</Button>]}>
                  <Tag color="blue" className="category-tag">{project.category}</Tag>
                  <Title level={4} className="project-title">{project.name}</Title>
                  <Paragraph className="project-description">{project.description}</Paragraph>
                  <Text type="secondary" className="project-author">By: {project.submitted_by.slice(0, 6)}...{project.submitted_by.slice(-4)}</Text>
                </Card>
              ))}
            </div>
          )}
        </Card>
      </div>
    </div>
  );
};

export default App;
EON
echo "-> Created src/App.tsx."

# Create frontend/src/index.tsx
cat << 'EON' > frontend/src/index.tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import { AptosWalletAdapterProvider } from "@aptos-labs/wallet-adapter-react";
import { PetraWallet } from "petra-plugin-wallet-adapter";
import { ConfigProvider } from 'antd';
import App from './App';
import './index.css';

const wallets = [new PetraWallet()];

const theme = {
  token: {
    colorPrimary: '#667eea',
    fontFamily: "'Inter', sans-serif",
    borderRadius: 12,
  },
  components: {
    Card: {
      borderRadius: 20,
      boxShadow: "0 8px 32px rgba(0, 0, 0, 0.1)",
      border: "none",
    },
    Button: {
      borderRadius: 12,
    }
  }
};

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);
root.render(
  <React.StrictMode>
    <AptosWalletAdapterProvider plugins={wallets} autoConnect={true}>
      <ConfigProvider theme={theme}>
        <App />
      </ConfigProvider>
    </AptosWalletAdapterProvider>
  </React.StrictMode>
);
EON
echo "-> Created src/index.tsx."

# Create frontend/src/App.css
cat << 'EON' > frontend/src/App.css
/* General Body Styles */
body {
  margin: 0;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
}

/* App Container */
.app {
  padding: 20px;
}

/* Header */
.app-header {
  text-align: center;
  margin-bottom: 40px;
  color: white;
}
.app-title {
  color: white !important;
  font-size: 3rem !important;
  font-weight: 700 !important;
  margin-bottom: 10px !important;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}
.app-subtitle {
  font-size: 1.2rem !important;
  opacity: 0.9;
  color: white !important;
}

/* Stats */
.stats-container {
  display: flex;
  justify-content: center;
  gap: 30px;
  margin-top: 30px;
}
.stat-card {
  background: rgba(255, 255, 255, 0.2) !important;
  border-radius: 15px !important;
  text-align: center;
  backdrop-filter: blur(10px);
  min-width: 120px;
}
.stat-card .ant-card-body { padding: 20px !important; }
.stat-card h2 { color: white !important; margin-bottom: 5px !important; font-size: 2rem !important; }
.stat-card .ant-typography { color: white !important; opacity: 0.8; text-transform: uppercase; letter-spacing: 0.5px; font-size: 0.9rem; }

/* Main Layout */
.app-content {
  max-width: 1200px;
  margin: 0 auto;
}
.main-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 30px;
  margin-bottom: 40px;
}

/* Wallet Card */
.wallet-card {
  margin-bottom: 30px;
}
.wallet-card .ant-card-body { padding: 40px !important; }
.wallet-connect, .wallet-connected { text-align: center; }
.wallet-connect h3 { color: #667eea !important; margin-bottom: 15px !important; }
.connection-status {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  background: rgba(102, 126, 234, 0.1);
  padding: 10px 20px;
  border-radius: 25px;
  margin-bottom: 20px;
}
.status-dot {
  width: 8px;
  height: 8px;
  background: #52c41a;
  border-radius: 50%;
  animation: pulse 2s infinite;
}
@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.5; }
  100% { opacity: 1; }
}

/* General Card Styles */
.form-card, .actions-card, .projects-card {
  transition: transform 0.3s ease;
}
.form-card:hover, .actions-card:hover, .projects-card:hover {
  transform: translateY(-5px);
}
.form-card .ant-card-head-title, .actions-card .ant-card-head-title, .projects-card .ant-card-head-title {
  color: #667eea !important;
  font-weight: 600 !important;
}

/* Contract Info */
.contract-info {
  background: rgba(102, 126, 234, 0.1);
  padding: 15px;
  border-radius: 10px;
  margin-top: 15px;
}
.contract-info h5 { color: #667eea !important; margin-bottom: 10px !important; }
.contract-address { font-family: 'Monaco', monospace; font-size: 0.9rem; word-break: break-all; }

/* Projects Grid */
.loading-container, .empty-state {
  text-align: center;
  padding: 60px 20px;
}
.loading-container .ant-spin { margin-bottom: 20px; }
.empty-state h4 { color: #667eea !important; margin-bottom: 15px !important; }
.projects-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 20px;
}
.project-card {
  background: linear-gradient(135deg, #f8f9ff 0%, #e8ecff 100%) !important;
  border: 1px solid rgba(102, 126, 234, 0.2) !important;
  transition: all 0.3s ease;
}
.project-card:hover {
  transform: translateY(-3px);
  border-color: #667eea !important;
  box-shadow: 0 5px 20px rgba(102, 126, 234, 0.2) !important;
}
.category-tag { margin-bottom: 10px; font-weight: 600; }
.project-title { color: #2c3e50 !important; margin-bottom: 15px !important; font-size: 1.3rem !important; }
.project-description { color: #555 !important; line-height: 1.6; margin-bottom: 15px !important; }
.project-author { font-family: 'Monaco', monospace; font-size: 0.9rem; }

/* Custom Component Styles */
.ant-btn-primary {
  background: linear-gradient(45deg, #667eea, #764ba2) !important;
  border: none !important;
  font-weight: 600 !important;
  transition: all 0.3s ease !important;
}
.ant-btn-primary:hover {
  transform: translateY(-2px) !important;
  box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4) !important;
}
.ant-form-item-label > label { font-weight: 600 !important; color: #555 !important; }

/* Responsive Adjustments */
@media (max-width: 992px) {
  .main-grid {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 768px) {
  .stats-container { flex-direction: column; align-items: center; gap: 15px; }
  .app-title { font-size: 2rem !important; }
}
EON
echo "-> Created src/App.css."

# Create an empty index.css, as antd reset is imported in index.tsx
cat << 'EON' > frontend/src/index.css
/*
  We import Ant Design's reset CSS directly in index.tsx now,
  so this file can be used for additional global styles if needed.
*/
body {
  background-color: #f0f2f5;
}
EON
echo "-> Created src/index.css."

echo "✅ Frontend files and directories created successfully!"

EOF
