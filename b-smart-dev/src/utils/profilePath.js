// Vendors and members are rendered on different profile pages — always route
// through this helper instead of hardcoding `/profile/:id` so vendor accounts
// don't get sent to the member profile page.
export const getProfilePath = (user) => {
  const id = user?._id || user?.id;
  return user?.role === 'vendor' ? `/vendor/${id}/public` : `/profile/${id}`;
};
