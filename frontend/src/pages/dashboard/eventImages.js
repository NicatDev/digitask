/** API: `images` massivi və ya köhnə tək `image`. */

export function getEventImageUrls(event) {
    if (!event) return [];
    if (Array.isArray(event.images) && event.images.length > 0) {
        return event.images.map((x) => x?.image).filter(Boolean);
    }
    if (event.image) return [event.image];
    return [];
}
