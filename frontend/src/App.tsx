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
                <div className="connection-status"><div className="status-dot" /><Text>Connected: {account?.address.toString().slice(0, 6)}...{account?.address.toString().slice(-4)}</Text></div>
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
