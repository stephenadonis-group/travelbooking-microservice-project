import axios from 'axios';
import { getAuthHeader } from '../utils/helpers';

const BASE_URL =
  process.env.REACT_APP_NOTIFICATION_SERVICE || '/api/notifications';

const authHeaders = () => ({
  ...getAuthHeader(),
  'Content-Type': 'application/json',
});

/**
 * Fetch all notifications for the authenticated user.
 * @returns {Promise<object[]>}
 */
export const getUserNotifications = async () => {
  const response = await axios.get(`${BASE_URL}/my-notifications`, {
    headers: authHeaders(),
  });
  return response.data;
};

/**
 * Mark a notification as read by its ID.
 * @param {string} notificationId
 * @returns {Promise<object>}
 */
export const markAsRead = async (notificationId) => {
  const response = await axios.patch(
    `${BASE_URL}/${notificationId}/read`,
    {},
    { headers: authHeaders() }
  );
  return response.data;
};

/**
 * Mark all notifications as read.
 * @returns {Promise<object>}
 */
export const markAllAsRead = async () => {
  const response = await axios.patch(
    `${BASE_URL}/mark-all-read`,
    {},
    { headers: authHeaders() }
  );
  return response.data;
};

const notificationService = { getUserNotifications, markAsRead, markAllAsRead };
export default notificationService;
