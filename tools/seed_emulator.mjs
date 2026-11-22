// Seeds the local Firebase Emulator Suite with test users and messages.
// Spice #1 (Emulator Explorer). Production is never touched: every request
// goes to 127.0.0.1, and the Firestore writes use the emulator-only
// "Bearer owner" token, which real Firestore does not accept.
//
//   firebase emulators:start --only auth,firestore
//   node tools/seed_emulator.mjs
const PROJECT = process.env.PROJECT_ID ?? 'messageboard-c2e77';
const AUTH = 'http://127.0.0.1:9099';
const FIRESTORE = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;

const users = [
  { email: 'ada@test.com', first: 'Ada', last: 'Lovelace', role: 'student' },
  { email: 'grace@test.com', first: 'Grace', last: 'Hopper', role: 'instructor' },
  { email: 'alan@test.com', first: 'Alan', last: 'Turing', role: 'other' },
];
const PASSWORD = 'test1234';

const messages = [
  [0, 'First! The board is live.'],
  [1, 'Streams beat refresh buttons.'],
  [0, 'Rules, not hidden buttons.'],
  [2, 'Seeded from the emulator — production is untouched.'],
  [1, 'Try editing my message as Ada. The rules will say no.'],
];

async function call(url, body, headers = {}) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`${url} -> ${res.status} ${JSON.stringify(json)}`);
  return json;
}

const asOwner = { Authorization: 'Bearer owner' };
const str = (v) => ({ stringValue: v });
const time = (d) => ({ timestampValue: d.toISOString() });

const uids = [];
for (const u of users) {
  const r = await call(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key`,
    { email: u.email, password: PASSWORD, returnSecureToken: true },
  );
  uids.push(r.localId);
  await call(
    `${FIRESTORE}/users?documentId=${r.localId}`,
    {
      fields: {
        uid: str(r.localId),
        firstName: str(u.first),
        lastName: str(u.last),
        role: str(u.role),
        registrationDateTime: time(new Date()),
      },
    },
    asOwner,
  );
  console.log(`user     ${u.email.padEnd(16)} uid=${r.localId}`);
}

const start = Date.now() - messages.length * 60_000;
for (const [i, [who, text]] of messages.entries()) {
  const u = users[who];
  await call(
    `${FIRESTORE}/messages`,
    {
      fields: {
        text: str(text),
        authorUid: str(uids[who]),
        authorName: str(`${u.first} ${u.last}`),
        createdAt: time(new Date(start + i * 60_000)),
      },
    },
    asOwner,
  );
  console.log(`message  ${u.first.padEnd(6)} "${text}"`);
}

console.log(`\nSeeded ${users.length} users and ${messages.length} messages into project "${PROJECT}" (emulator).`);
console.log(`Sign in with any seeded email and password "${PASSWORD}".`);
console.log('Emulator UI: http://127.0.0.1:4000');
