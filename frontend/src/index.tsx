import React from 'react';
import ReactDOM from 'react-dom/client';
import { AptosWalletAdapterProvider } from "@aptos-labs/wallet-adapter-react";
import { PetraWallet } from "petra-plugin-wallet-adapter";
import { ConfigProvider } from 'antd';
import App from './App.tsx';
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
