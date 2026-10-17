// Deterministic, clearly labeled example BotC games for UI previews.
// The generated IDs and provenance marker make the demo set identifiable.
// This module never connects to Firebase or writes anything.
import { createHash } from 'node:crypto';

export const DEMO_SET = 'botc-ui-preview-v1';
export const MAX_DEMO_GAMES = 120;
export const DEMO_PREFIX = 'game_demo_v1_';

const standardScripts = [
  {
    id: 'standard:trouble_brewing',
    name: 'Trouble Brewing',
    townsfolk: [
      'washerwoman','librarian','investigator','chef','empath','fortuneteller',
      'mayor','monk','ravenkeeper','slayer','soldier','undertaker','virgin',
    ],
    outsiders: ['butler','drunk','recluse','saint'],
    minions: ['baron','poisoner','scarletwoman','spy'],
    demons: ['imp'],
    travellers: ['scapegoat','gunslinger','beggar','bureaucrat','thief'],
  },
  {
    id: 'standard:bad_moon_rising',
    name: 'Bad Moon Rising',
    townsfolk: [
      'grandmother','sailor','chambermaid','exorcist','innkeeper','gambler',
      'gossip','courtier','professor','minstrel','tealady','pacifist','fool',
    ],
    outsiders: ['goon','lunatic','tinker','moonchild'],
    minions: ['godfather','devilsadvocate','assassin','mastermind'],
    demons: ['zombuul','pukka','shabaloth','po'],
    travellers: ['apprentice','matron','voudon','judge','bishop'],
  },
  {
    id: 'standard:sects_and_violets',
    name: 'Sects & Violets',
    townsfolk: [
      'clockmaker','dreamer','snakecharmer','mathematician','flowergirl',
      'towncrier','oracle','savant','seamstress','philosopher','artist',
      'juggler','sage',
    ],
    outsiders: ['mutant','sweetheart','barber','klutz'],
    minions: ['eviltwin','witch','cerenovus','pithag'],
    demons: ['fanggu','vigormortis','nodashii','vortox'],
    travellers: ['butcher','bonecollector','harlot','barista','deviant'],
  },
];
const customScript = {
  id: 'custom:demo-mystic',
  name: 'Demo: Mystische Nacht',
  isCustom: true,
  townsfolk: [
    'washerwoman','chef','empath','fortuneteller','monk','undertaker',
    'dreamer','flowergirl','savant','seamstress','gossip','innkeeper','fool',
  ],
  outsiders: ['drunk','recluse','mutant','lunatic'],
  minions: ['poisoner','scarletwoman','witch','assassin'],
  demons: ['imp','vortox','po'],
  travellers: [],
};
export const DEMO_SCRIPTS = [...standardScripts, customScript].map((script) => {
  const roleIds = [
    ...script.townsfolk, ...script.outsiders,
    ...script.minions, ...script.demons, ...script.travellers,
  ];
  return {
    ...script,
    roleIds,
    contentHash: createHash('sha256')
      .update(JSON.stringify({ roleIds })).digest('hex'),
  };
});

function randomizer(seed) {
  let state = (seed ^ 0x9e3779b9) >>> 0;
  return () => {
    state = (Math.imul(1664525, state) + 1013904223) >>> 0;
    return state / 0x100000000;
  };
}
function chooseUnique(source, amount, random) {
  const unused = [...source];
  const selected = [];
  for (let i = 0; i < amount; i++) {
    const position = Math.floor(random() * unused.length);
    selected.push(unused.splice(position, 1)[0]);
  }
  return selected;
}
function shuffled(items, random) {
  return chooseUnique(items, items.length, random);
}
function composition(playerCount) {
  // Standard BotC base setup (townsfolk/outsider/minion/demon).
  const outsider = [0, 0, 1, 0, 1, 2, 0, 1, 2, 0, 1, 2][playerCount - 4];
  const minion = playerCount <= 9 ? 1 : playerCount <= 12 ? 2 : 3;
  const demon = 1;
  return { townsfolk: playerCount - outsider - minion - demon,
    outsider, minion, demon };
}

export function demoGame(index) {
  if (!Number.isSafeInteger(index) || index < 1 || index > MAX_DEMO_GAMES) {
    throw new RangeError('demo index must be 1..120');
  }
  const rng = randomizer(index * 1171 + 2026);
  const bucket = index % 20;
  const script = DEMO_SCRIPTS[bucket < 10 ? 0 : bucket < 15 ? 1 : bucket < 19 ? 2 : 3];
  const playerCount = 5 + Math.floor(rng() * 11);
  const setup = composition(playerCount);
  const roster = shuffled([
    ...chooseUnique(script.townsfolk, setup.townsfolk, rng)
      .map((roleId) => ({ roleId, team: 'good' })),
    ...chooseUnique(script.outsiders, setup.outsider, rng)
      .map((roleId) => ({ roleId, team: 'good' })),
    ...chooseUnique(script.minions, setup.minion, rng)
      .map((roleId) => ({ roleId, team: 'evil' })),
    ...chooseUnique(script.demons, setup.demon, rng)
      .map((roleId) => ({ roleId, team: 'evil' })),
  ], rng);

  const winnerTeam = rng() < (script.isCustom ? 0.56 : 0.49) ? 'good' : 'evil';
  const nights = 2 + Math.floor(rng() * 5);
  const totalDurationMs = (62 + Math.floor(rng() * 150)) * 60_000;
  const startedAt = new Date(Date.UTC(2026, 8, 5 + index % 40,
    17 + index % 4, 0, 0));
  const endedAt = new Date(startedAt.getTime() + totalDurationMs);
  const gameId = DEMO_PREFIX + String(index).padStart(4, '0');
  const players = roster.map((role, position) => ({
    anonymizedPlayerId: 'player_demo_' + String(index).padStart(4, '0') +
      '_' + String(position).padStart(2, '0'),
    position,
    actualStartRoleId: role.roleId,
    displayedStartRoleId: role.roleId === 'drunk'
      ? script.townsfolk[position % script.townsfolk.length] : role.roleId,
    startTeam: role.team,
    endRoleId: role.roleId,
    endTeam: role.team,
  }));
  // Low-frequency role / team changes mimic real, but rare, BotC interactions.
  // The numbers are illustrative, not measured gameplay outcomes.
  if (index % 7 === 0) {
    const player = players.find((p) => p.startTeam === 'good');
    if (player) {
      player.endTeam = 'evil';
      player.endRoleId = script.demons[Math.floor(rng() * script.demons.length)];
    }
  }
  const phaseCount = nights * 2 - 1;
  const phaseWeights = Array.from({ length: phaseCount }, (_, i) =>
    i % 2 === 0 ? 8 + Math.floor(rng() * 8) : 16 + Math.floor(rng() * 12));
  const weightSum = phaseWeights.reduce((a,b) => a+b, 0);
  let current = startedAt.getTime();
  const phases = phaseWeights.map((weight, i) => {
    const remaining = endedAt.getTime() - current;
    const durationMs = i === phaseCount-1 ? remaining
      : Math.floor(totalDurationMs * weight / weightSum);
    const phase = {
      phaseId: 'phase_demo_' + String(index).padStart(4,'0') + '_' + String(i),
      type: i%2 === 0 ? 'night' : 'day',
      round: Math.floor(i/2)+1,
      startedAt: new Date(current).toISOString(),
      endedAt: new Date(current + durationMs).toISOString(),
      durationMs,
    };
    current += durationMs;
    return phase;
  });
  const events = [];
  let eventIndex = 0;
  const dead = new Set();
  for (const phase of phases) {
    if (phase.type !== 'day') continue;
    const count = 1 + Math.floor(rng()*3);
    for (let j=0; j<count; j++) {
      const victimIndex = Math.floor(rng()*players.length);
      const isRevival = dead.has(victimIndex) && rng() < 0.18;
      if (!isRevival && dead.has(victimIndex)) continue;
      if (isRevival) dead.delete(victimIndex);
      else dead.add(victimIndex);
      const occurredAt = new Date(
        new Date(phase.startedAt).getTime()
          + Math.floor((j+1)/(count+1)*phase.durationMs));
      events.push({
        eventId: 'event_demo_' + String(index).padStart(4,'0') + '_' + String(eventIndex++),
        occurredAt: occurredAt.toISOString(),
        type: 'lifeStatusChanged',
        phase: 'day', round: phase.round,
        targetPlayerIds: [players[victimIndex].anonymizedPlayerId],
        data: { flags: { alive: isRevival } },
      });
    }
  }
  return {
    schemaVersion: 1,
    gameId,
    startedAt: startedAt.toISOString(),
    endedAt: endedAt.toISOString(),
    totalDurationMs,
    playerCount,
    winnerTeam,
    script: {
      scriptId: script.id,
      name: script.name,
      isCustom: Boolean(script.isCustom),
      roleIds: script.roleIds,
      contentHash: script.contentHash,
    },
    players, phases, chronicleEvents: events,
    // Only the ADMIN seed workflow can create this non-public-schema marker.
    demo: true,
    demoSet: DEMO_SET,
  };
}
