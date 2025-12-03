// ws-diagnose.js
// Usage:
//   node ws-diagnose.js ws://host:port/path
// Optionally set AUTH_TOKEN env var to include Authorization in initial payload.

const WebSocket = require('ws');

const url = process.argv[2] || 'ws://localhost:4000/graphql';
const AUTH = process.env.AUTH_TOKEN || '';
const sampleInitPayload = {};
if (AUTH) sampleInitPayload.Authorization = AUTH;

function trySubscriptionsTransportWs(target) {
  return new Promise((resolve) => {
    console.log('\n=== Testing subscriptions-transport-ws against', target, '===');
    const ws = new WebSocket(target);
    ws.on('open', () => {
      console.log('connected');
      const init = JSON.stringify({ type: 'connection_init', payload: sampleInitPayload });
      console.log('->', init);
      ws.send(init);
      setTimeout(() => {
        const start = JSON.stringify({
          id: '1',
          type: 'start',
          payload: {
            query: 'subscription { __typename }',
            variables: {}
          }
        });
        console.log('->', start);
        ws.send(start);
      }, 1000);
    });
    ws.on('message', (msg) => {
      console.log('<-', msg.toString());
    });
    ws.on('close', (code, reason) => {
      console.log('closed', code, reason && reason.toString());
      resolve();
    });
    ws.on('error', (e) => {
      console.error('error', e && e.message ? e.message : e);
      resolve();
    });
    setTimeout(() => {
      try { ws.close(); } catch (e) {}
    }, 6000);
  });
}

function tryGraphqlWs(target) {
  return new Promise((resolve) => {
    console.log('\n=== Testing graphql-ws (modern) against', target, '===');
    const ws = new WebSocket(target);
    ws.on('open', () => {
      console.log('connected');
      const init = JSON.stringify({ type: 'connection_init', payload: sampleInitPayload });
      console.log('->', init);
      ws.send(init);
      setTimeout(() => {
        const subscribeMsg = JSON.stringify({
          id: '1',
          type: 'subscribe',
          payload: {
            query: 'subscription { __typename }',
            variables: {}
          }
        });
        console.log('->', subscribeMsg);
        ws.send(subscribeMsg);
      }, 1000);
    });
    ws.on('message', (msg) => {
      console.log('<-', msg.toString());
    });
    ws.on('close', (code, reason) => {
      console.log('closed', code, reason && reason.toString());
      resolve();
    });
    ws.on('error', (e) => {
      console.error('error', e && e.message ? e.message : e);
      resolve();
    });
    setTimeout(() => {
      try { ws.close(); } catch (e) {}
    }, 6000);
  });
}

(async () => {
  const target = url;
  console.log('WS diagnose target:', target);
  if (AUTH) console.log('Using AUTH_TOKEN from env (masked)');
  await trySubscriptionsTransportWs(target);
  await new Promise(r => setTimeout(r, 500));
  await tryGraphqlWs(target);
  console.log('\nDiagnosis run complete.');
})();
