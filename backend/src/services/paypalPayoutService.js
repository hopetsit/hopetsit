/**
 * PayPal Payout Service - Sitter Earnings
 *
 * Uses PayPal Payouts API (v1) to send payouts from the platform PayPal
 * account to sitters after successful PayPal booking payments.
 *
 * This module is intentionally separate from the main paypalService (Orders API)
 * to avoid changing the existing payment flow.
 */

const https = require('https');

const getPaypalApiBaseUrl = () => {
  const env = process.env.PAYPAL_ENVIRONMENT === 'live' ? 'live' : 'sandbox';
  return env === 'live'
    ? 'api-m.paypal.com'
    : 'api-m.sandbox.paypal.com';
};

const getPaypalCredentials = () => {
  const clientId = process.env.PAYPAL_CLIENT_ID;
  const clientSecret = process.env.PAYPAL_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error('PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET must be configured for payouts.');
  }

  return { clientId, clientSecret };
};

const httpRequest = ({ hostname, path, method, headers, body }) => {
  return new Promise((resolve, reject) => {
    const options = {
      hostname,
      path,
      method,
      headers,
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        const statusCode = res.statusCode || 500;
        let parsed;
        try {
          parsed = data ? JSON.parse(data) : {};
        } catch (err) {
          return reject(
            new Error(`PayPal response parse error (status ${statusCode}): ${data || err.message}`)
          );
        }

        if (statusCode >= 200 && statusCode < 300) {
          return resolve(parsed);
        }

        const message =
          parsed && (parsed.message || parsed.error_description)
            ? `${parsed.message || parsed.error_description}`
            : `PayPal API error (status ${statusCode})`;
        const error = new Error(message);
        error.statusCode = statusCode;
        error.details = parsed;
        return reject(error);
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    if (body) {
      req.write(body);
    }

    req.end();
  });
};

const getAccessToken = async () => {
  const { clientId, clientSecret } = getPaypalCredentials();
  const hostname = getPaypalApiBaseUrl();

  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const body = 'grant_type=client_credentials';

  const response = await httpRequest({
    hostname,
    path: '/v1/oauth2/token',
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body),
    },
    body,
  });

  if (!response.access_token) {
    throw new Error('Unable to obtain PayPal access token for payouts.');
  }

  return response.access_token;
};

const getPayoutBatchDetails = async ({ accessToken, payoutBatchId }) => {
  if (!payoutBatchId || typeof payoutBatchId !== 'string') {
    throw new Error('payoutBatchId is required to fetch payout batch details.');
  }

  const hostname = getPaypalApiBaseUrl();
  return httpRequest({
    hostname,
    path: `/v1/payments/payouts/${encodeURIComponent(payoutBatchId)}`,
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
  });
};

/**
 * Send a PayPal payout to a sitter.
 *
 * @param {Object} params
 * @param {string} params.bookingId - Internal booking ID (Mongo ObjectId as string)
 * @param {string} params.sitterEmail - Sitter's PayPal email address
 * @param {number} params.amount - Payout amount (major units, e.g. 80.0)
 * @param {string} params.currency - Currency code (e.g. 'EUR', 'USD')
 * @returns {Promise<{ batchId: string, payoutItemId: string }>}
 */
const sendPayoutToSitter = async ({ bookingId, sitterEmail, amount, currency }) => {
  if (!bookingId || typeof bookingId !== 'string') {
    throw new Error('bookingId is required to send payout.');
  }
  if (!sitterEmail || typeof sitterEmail !== 'string') {
    throw new Error('sitterEmail is required to send payout.');
  }
  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
    throw new Error('Payout amount must be a positive number.');
  }
  if (!currency || typeof currency !== 'string' || !currency.trim()) {
    throw new Error('Currency is required to send payout.');
  }

  const normalizedCurrency = currency.trim().toUpperCase();
  const valueString = amount.toFixed(2);

  const hostname = getPaypalApiBaseUrl();
  const accessToken = await getAccessToken();

  const senderBatchId = `batch_${bookingId}_${Date.now()}`;

  const payload = {
    sender_batch_header: {
      sender_batch_id: senderBatchId,
      email_subject: 'You received a payment',
    },
    items: [
      {
        recipient_type: 'EMAIL',
        amount: {
          value: valueString,
          currency: normalizedCurrency,
        },
        receiver: sitterEmail.trim(),
        note: `Payout for booking ${bookingId}`,
        sender_item_id: bookingId,
      },
    ],
  };

  console.log('➡️ Sending PayPal payout', {
    bookingId,
    sitterEmail: sitterEmail.trim(),
    amount: valueString,
    currency: normalizedCurrency,
    senderBatchId,
  });

  const body = JSON.stringify(payload);

  const response = await httpRequest({
    hostname,
    // Async mode (default). PayPal is deprecating sync_mode for new integrations.
    path: '/v1/payments/payouts',
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    },
    body,
  });

  console.log('✅ PayPal payout response', {
    bookingId,
    sitterEmail: sitterEmail.trim(),
    response,
  });

  const batchId = response?.batch_header?.payout_batch_id || null;
  let payoutItemId = null;

  // In async mode PayPal may not return items immediately; fetch the batch details to obtain item id.
  if (batchId) {
    try {
      const details = await getPayoutBatchDetails({ accessToken, payoutBatchId: batchId });
      const items = Array.isArray(details?.items) ? details.items : [];
      payoutItemId = items[0]?.payout_item_id || null;
    } catch (err) {
      console.warn('⚠️ Unable to fetch PayPal payout batch details', {
        bookingId,
        batchId,
        error: err?.message || String(err),
      });
    }
  }

  if (!batchId || !payoutItemId) {
    throw new Error('PayPal payout did not return expected batch or item identifiers.');
  }

  return {
    batchId,
    payoutItemId,
  };
};

module.exports = {
  sendPayoutToSitter,
};

