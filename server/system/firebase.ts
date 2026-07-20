import { getApps, initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore } from 'firebase-admin/firestore'

if (getApps().length === 0) initializeApp()

export const db = () => getFirestore()

// Wrapped rather than imported straight from firebase-admin at the call site, so a
// test can replace it the same way it replaces `db`.
export const auth = () => getAuth()
