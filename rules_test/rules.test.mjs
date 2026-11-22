// Automated security-rules tests (Spice #2), run against the Firestore emulator:
//
//   firebase emulators:exec --only firestore "npm --prefix rules_test test"
//
// Every denial here is decided by firestore.rules, not by app code.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  collection,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
} from 'firebase/firestore';

// Expected denials make the SDK log warnings; keep the test output readable.
setLogLevel('silent');

const ADA = 'uid_ada';
const GRACE = 'uid_grace';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-message-board',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Seed with rules disabled: one message by Ada, plus both user records.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'messages/ada_msg'), {
      text: 'Hello from Ada',
      authorUid: ADA,
      authorName: 'Ada Lovelace',
      createdAt: new Date(),
    });
    for (const [uid, first] of [[ADA, 'Ada'], [GRACE, 'Grace']]) {
      await setDoc(doc(db, `users/${uid}`), {
        uid,
        firstName: first,
        lastName: 'Test',
        role: 'student',
        registrationDateTime: new Date(),
      });
    }
  });
});

const signedOut = () => env.unauthenticatedContext().firestore();
const as = (uid) => env.authenticatedContext(uid).firestore();

const newMessage = (authorUid, text = 'Hi board') => ({
  text,
  authorUid,
  authorName: 'Test User',
  createdAt: serverTimestamp(),
});

describe('denials', () => {
  test('signed-out read of messages is denied', async () => {
    await assertFails(getDocs(collection(signedOut(), 'messages')));
  });

  test('signed-out create is denied', async () => {
    await assertFails(setDoc(doc(signedOut(), 'messages/x'), newMessage(ADA)));
  });

  test('cross-uid update is denied', async () => {
    await assertFails(
      updateDoc(doc(as(GRACE), 'messages/ada_msg'), {
        text: 'hijacked',
        editedAt: serverTimestamp(),
      }),
    );
  });

  test('cross-uid delete is denied', async () => {
    await assertFails(deleteDoc(doc(as(GRACE), 'messages/ada_msg')));
  });

  test('forged authorUid create is denied', async () => {
    await assertFails(
      setDoc(doc(as(GRACE), 'messages/forged'), newMessage(ADA)),
    );
  });

  test('owner cannot change authorUid or createdAt', async () => {
    const db = as(ADA);
    await assertFails(updateDoc(doc(db, 'messages/ada_msg'), { authorUid: GRACE }));
    await assertFails(
      updateDoc(doc(db, 'messages/ada_msg'), { createdAt: serverTimestamp() }),
    );
  });

  test('empty, over-long, or client-dated messages are denied', async () => {
    const db = as(ADA);
    await assertFails(setDoc(doc(db, 'messages/e'), newMessage(ADA, '')));
    await assertFails(setDoc(doc(db, 'messages/l'), newMessage(ADA, 'a'.repeat(501))));
    await assertFails(
      setDoc(doc(db, 'messages/d'), { ...newMessage(ADA), createdAt: new Date(0) }),
    );
  });

  test("reading another user's private record is denied", async () => {
    await assertFails(getDoc(doc(as(GRACE), `users/${ADA}`)));
  });

  test('user record cannot be updated or deleted (create-once)', async () => {
    const db = as(ADA);
    await assertFails(
      updateDoc(doc(db, `users/${ADA}`), { registrationDateTime: serverTimestamp() }),
    );
    await assertFails(deleteDoc(doc(db, `users/${ADA}`)));
  });

  test('user record with a bad role or extra field is denied', async () => {
    const db = as('uid_new');
    const base = {
      uid: 'uid_new',
      firstName: 'New',
      lastName: 'User',
      role: 'student',
      registrationDateTime: serverTimestamp(),
    };
    await assertFails(setDoc(doc(db, 'users/uid_new'), { ...base, role: 'admin' }));
    await assertFails(setDoc(doc(db, 'users/uid_new'), { ...base, isAdmin: true }));
  });
});

describe('correct-author CRUD is allowed', () => {
  test('signed-in user reads the board', async () => {
    await assertSucceeds(getDocs(collection(as(GRACE), 'messages')));
  });

  test('author creates, edits, and deletes own message', async () => {
    const db = as(GRACE);
    const ref = doc(db, 'messages/grace_msg');
    await assertSucceeds(setDoc(ref, newMessage(GRACE)));
    await assertSucceeds(
      updateDoc(ref, { text: 'Edited by Grace', editedAt: serverTimestamp() }),
    );
    await assertSucceeds(deleteDoc(ref));
  });

  test('new user creates and reads own record', async () => {
    const db = as('uid_new');
    await assertSucceeds(
      setDoc(doc(db, 'users/uid_new'), {
        uid: 'uid_new',
        firstName: 'New',
        lastName: 'User',
        role: 'other',
        registrationDateTime: serverTimestamp(),
      }),
    );
    await assertSucceeds(getDoc(doc(db, 'users/uid_new')));
  });
});
