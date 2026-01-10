const std = @import("std");

pub const Pad = struct {
    wave: i64,
    level: i64, // max 100,
    pan: u64,
    playMode: u8,
    output: u8,
    muteGroup: u8,
    tempoSync: bool,
    midiChannel: u64,
    midiNote: u64, // NoteNum
    midiCtrl: u64,
    loop: bool, // off, on, x2, x4, x8
    triggerType: u64, // shot, alt
    gateTime: u64,
    dynamics: bool,
    voiceAssign: bool,
    reverse: bool,
    subWave: u64,
    subWaveLevel: u64,
    subWavePan: u64,

    pub fn render(pad: Pad, writer: anytype) void {
        try writer.print(
            \\<PadPrm>
            \\    <Wv>{d}</Wv>
            \\    <WvLevel>{d}</WvLevel>
            \\    <WvPan>{d}</WvPan>
            \\    <PlayMode>{d}</PlayMode>
            \\    <OutAsgn>{d}</OutAsgn>
            \\    <MuteGrp>{d}</MuteGrp>
            \\    <TempoSync>{d}</TempoSync>
            \\    <PadMidiCh>{d}</PadMidiCh>
            \\    <NoteNum>{d}</NoteNum>
            \\    <MidiCtrl>{d}</MidiCtrl>
            \\    <Loop>{d}</Loop>
            \\    <TrigType>{d}</TrigType>
            \\    <GateTime>{d}</GateTime>
            \\    <Dynamics>{d}</Dynamics>
            \\    <VoiceAsgn>{d}</VoiceAsgn>
            \\    <Reverse>{d}</Reverse>
            \\    <SubWv>{d}</SubWv>
            \\    <SubWvLevel>{d}</SubWvLevel>
            \\    <SubWvPan>{d}</SubWvPan>
            \\</PadPrm>
        ,
            .{
                pad.wave,
                pad.level,
                pad.pan,
                pad.playMode,
                pad.output,
                pad.muteGroup,
                @intFromBool(pad.tempoSync),
                pad.midiChannel,
                pad.midiNote,
                pad.midiCtrl,
                @intFromBool(pad.loop),
                pad.triggerType,
                pad.gateTime,
                @intFromBool(pad.dynamics),
                @intFromBool(pad.voiceAssign),
                @intFromBool(pad.reverse),
                pad.subWave,
                pad.subWaveLevel,
                pad.subWavePan,
            },
        );
    }
};
