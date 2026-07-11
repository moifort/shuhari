/** Maximum decoded image size accepted (10 MB). Base64 adds ~33 % overhead,
 *  so the corresponding base64 string limit is ~14 MB of characters. */
export const MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024
export const MAX_BASE64_LENGTH = Math.ceil((MAX_IMAGE_SIZE_BYTES * 4) / 3)

/** Returns true when the base64-encoded image fits within the 10 MB decoded size limit. */
export const imageWithinSizeLimit = (base64Length: number): boolean =>
  base64Length <= MAX_BASE64_LENGTH

/** How many import photos a single request may carry. */
export const MAX_IMPORT_PHOTOS = 6
