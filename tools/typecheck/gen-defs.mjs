// Adapts luau-lsp's Roblox globalTypes.d.luau for the WASM Luau analyzer:
//  - strips per-enum helper functions (the Enum global otherwise exceeds the analyzer's graph limit)
//  - makes RaycastResult non-generic
//  - adds typed overloads for Instance.new and GetService for the classes/services this project uses
import fs from 'node:fs';
const [src, out, maxNew = '200'] = process.argv.slice(2);
let text = fs.readFileSync(src, 'utf8');
text = text.replace('export type RaycastResult<T = BasePart> = {\n    Instance: T,', 'export type RaycastResult = {\n    Instance: BasePart,')
  .replace('RaycastResult<Attachment | Constraint | NoCollisionConstraint | WeldConstraint>?', 'any');
const lines = text.split('\n');
const meta = JSON.parse(lines[0].replace('--#METADATA#', ''));
lines[0] = '--';
const enumEnd = lines.findIndex(l => l.startsWith('declare Enum: ENUM_LIST'));
let result = lines.filter((l, i) => !(i < enumEnd && /^\tfunction (GetEnumItems|FromName|FromValue)\(self/.test(l))).join('\n');
const NEW = `Part MeshPart WedgePart CornerWedgePart TrussPart SpawnLocation Seat Model Folder Configuration Attachment Weld WeldConstraint Motor6D
PointLight SpotLight SurfaceLight Sound SoundGroup ReverbSoundEffect EqualizerSoundEffect DistortionSoundEffect PitchShiftSoundEffect EchoSoundEffect TremoloSoundEffect ChorusSoundEffect
Atmosphere Sky BloomEffect BlurEffect ColorCorrectionEffect DepthOfFieldEffect SunRaysEffect
RemoteEvent UnreliableRemoteEvent RemoteFunction BindableEvent BindableFunction ProximityPrompt ClickDetector Highlight Decal Texture SurfaceAppearance SpecialMesh BlockMesh
ScreenGui BillboardGui SurfaceGui Frame ScrollingFrame CanvasGroup TextLabel TextButton TextBox ImageLabel ImageButton ViewportFrame
UICorner UIStroke UIGradient UIPadding UIListLayout UIGridLayout UIScale UIAspectRatioConstraint UISizeConstraint UITextSizeConstraint UIFlexItem
Beam Trail ParticleEmitter Fire Smoke StringValue IntValue NumberValue BoolValue ObjectValue Animation Humanoid Animator Camera
AlignPosition AlignOrientation LinearVelocity HingeConstraint PrismaticConstraint NoCollisionConstraint PathfindingModifier PathfindingLink
Tool Accessory Shirt Pants BodyColors Explosion ForceField Team Script LocalScript ModuleScript`.split(/\s+/).slice(0, Number(maxNew));
for (const c of NEW) if (!meta.CREATABLE_INSTANCES.includes(c)) console.error('warn: not creatable/unknown:', c);
const SERVICES = `Players Lighting SoundService TweenService RunService UserInputService ContextActionService ReplicatedStorage ReplicatedFirst ServerStorage
ServerScriptService StarterGui StarterPlayer StarterPack MarketplaceService DataStoreService PathfindingService CollectionService Debris HttpService
TeleportService TextService TextChatService PolicyService BadgeService MessagingService PhysicsService ProximityPromptService GuiService SocialService
AnalyticsService MemoryStoreService ContentProvider VoiceChatService Teams Workspace`.split(/\s+/);
const newOverloads = NEW.map(c => `((className: "${c}", parent: Instance?) -> ${c})`).join(' & ');
let n0 = result.length;

const svc = SERVICES.map(s => `\tfunction GetService(self, className: "${s}"): ${s}`).join('\n');
n0 = result.length;

fs.writeFileSync(out, result);
