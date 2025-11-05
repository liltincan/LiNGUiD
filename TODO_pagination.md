# TODO: Implement Pagination in fetchVideos Method

## Tasks
- [x] Modify the Firestore query in `fetchVideos` to order by document ID for stable sorting.
- [x] Add `startAfter` logic using the provided `afterID` to enable cursor-based pagination.
- [x] Apply the `limit` parameter at the query level to fetch only the necessary number of documents.
- [x] Adjust client-side filtering (unwatched videos and level-based) and sorting (by engagement score) to work with paginated results.
- [x] Ensure the implementation handles multiple selected languages correctly.
- [ ] Test the updated method for correctness, including edge cases like no `afterID`, large limits, and empty results.

## Followup Steps
- [ ] Run unit tests or integration tests to verify pagination behavior.
- [ ] Monitor Firestore performance and costs after implementation.
- [ ] Update any dependent views (e.g., VideoPlayerView) if needed for pagination UI.
