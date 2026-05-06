PromoteReels
Promote reel management — reels with attached product listings



POST
/api/promote-reels
Create a new promote reel



GET
/api/promote-reels
List all promote reels (paginated)



GET
/api/promote-reels/{id}
Get a promote reel by ID



PATCH
/api/promote-reels/{id}
Update a promote reel (caption, location, tags, products, etc.)



DELETE
/api/promote-reels/{id}
Delete a promote reel (soft delete)



POST
/api/promote-reels/{id}/like
Like a promote reel



POST
/api/promote-reels/{id}/unlike
Unlike a promote reel



GET
/api/promote-reels/{id}/likes
Get users who liked a promote reel



POST
/api/promote-reels/{promoteReelId}/comments
Add a comment (or reply) to a promote reel



GET
/api/promote-reels/{promoteReelId}/comments
Get top-level comments for a promote reel



DELETE
/api/promote-reels/comments/{id}
Delete a comment on a promote reel



GET
/api/promote-reels/comments/{commentId}/replies
Get replies for a comment on a promote reel



DELETE
/api/promote-reels/comments/{commentId}/replies/{replyId}
Delete a specific reply on a promote reel comment



POST
/api/promote-reels/comments/{commentId}/like
Like a comment on a promote reel



POST
/api/promote-reels/comments/{commentId}/unlike
Unlike a comment on a promote reel


