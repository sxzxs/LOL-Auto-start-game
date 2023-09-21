/************************************************************************
 * @description 
 * @file LOL自动开始游戏.ah2
 * @author zzZ 2397633100@qq.com 交流qq群 620432927
 * @date 2023/09/21
 * @version 0.0.0
 ***********************************************************************/
;http://static.developer.riotgames.com/docs/lol/queues.json

#Requires AutoHotkey v2.0
#include <cimgui>
#include <WinHttpRequest>
#include <log>

logger.is_log_open := false
logger.is_use_editor := false

main()
main()
{
    global lol_api := Lcu()
    global g_json_path := A_ScriptDir . "/config/setting.json"
    ;配置
    global g_is_auto_create_room := true
    global g_is_auto_start_game := true
    global g_is_auto_receive_game := true
    global g_room_type := 450
    global g_is_auto_next_game := true
    global g_is_start := false
    global g_game_status := ''

    ;LOL游戏循环
    SetTimer(lol_loop, 500)

    ;Register exited functions, Variables that need to be cleared for ctypes binding
    OnExit ExitFunc
    ui := Imgui()
    ui.enableviewports(false)
    ui.load_font_range(A_ScriptDir '/font/ImguiText.txt', &range_array := [], &length := 0, &raw_data)
    hwnd := ui.gui_create("AHK ImGui", 500, 500, 0, 0, 0, 0,,,, raw_data)
    change_window_icon(hwnd, A_ScriptDir "\image\main.ico")
    WinShow(hwnd)

    io := ui.igGetIO()
    global g_io := ImGuiIO_AHK.from_ptr(io) ;ctypes from_ptr 对象，需要主动释放
    imgui.ctype_bind_var.Push('g_io')

    is_open_demo := false
    is_open_main := true 
    while(ui.peekmsg())
    {
        ui.beginframe()
        if(is_open_demo)
            ui.igShowDemoWindow(&is_open_demo)

        if(is_open_main)
        {
            main_view_port := ui.igGetMainViewport()
            g_main_view_port := ImGuiViewport.from_ptr(main_view_port)
            ui.igSetNextWindowPos(ImVec2([g_main_view_port.WorkPos.x, g_main_view_port.WorkPos.y]))
            ui.igSetNextWindowSize(ImVec2([g_main_view_port.WorkSize.x, g_main_view_port.WorkSize.y]))
            static flags := ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings
            static mode := '大乱斗'
            if(ui.igBegin(ui.str('main'), &is_open_main, flags))
            {
                ui.igRadioButton_IntPtr(ui.str('大乱斗'), &g_room_type, 450)
                ui.igRadioButton_IntPtr(ui.str('云顶匹配'), &g_room_type, 1090), ui.igSameLine()
                ui.igRadioButton_IntPtr(ui.str('云顶排位'), &g_room_type, 1100), ui.igSameLine()
                ui.igRadioButton_IntPtr(ui.str('云顶狂暴'), &g_room_type, 1130), ui.igSameLine()
                ui.igRadioButton_IntPtr(ui.str('云顶双人'), &g_room_type, 1160)
                ui.igRadioButton_IntPtr(ui.str('匹配模式'), &g_room_type, 430), ui.igSameLine()
                ui.igRadioButton_IntPtr(ui.str('排位赛'), &g_room_type, 420), ui.igSameLine()
                ui.igRadioButton_IntPtr(ui.str('灵活组排'), &g_room_type, 440)

                ui.igCheckbox(ui.str('是否开启'), &g_is_start)
                ui.igCheckbox(ui.str('是否创建房间'), &g_is_auto_create_room)
                ui.igCheckbox(ui.str('是否自动开始'), &g_is_auto_start_game)
                ui.igCheckbox(ui.str('是否接受对局'), &g_is_auto_receive_game)
                ui.igCheckbox(ui.str('是否自动下一局'), &g_is_auto_next_game)
                ui.igTextUnformatted(ui.str(g_game_status))
            }
            ui.igEnd()
        }
        ui.endframe()
    }
    ExitApp
}


ExitFunc(ExitReason, ExitCode)
{
    global
    for k,v in imgui.ctype_bind_var
    {
        %v% := ''
    }
}

change_window_icon(hwnd, ico_path)
{
    hIcon := DllCall( "LoadImage", 'UInt',0, 'Str', ico_path, 'uint',1, 'UInt',0, 'UInt',0, 'UInt',0x10 )
    SendMessage(0x80, 0, hIcon,, hwnd)
    SendMessage(0x80, 1, hIcon,, hwnd)
}


lol_loop(*)
{
    global g_game_status
    if(!g_is_start)
        return

    if(lol_api.get_game_status(&status))
    {
        logger.info(lol_api.get_game_status_string(status))
        g_game_status := lol_api.get_game_status_string(status)
    }
    else
    {
        MsgBox('获取状态失败，请先打开客户端，然后管理员模式运行!!!')
        ExitApp
    }


    switch(status)
    {
        case 'None':
        {
            if(g_is_auto_create_room)
            {
                logger.in('创建房间')
                que_id := g_room_type
                rtn := lol_api.create_room(que_id)
                logger.out(rtn)
            }
        }
        case 'Lobby':
        {
            ;房间中
            if(g_is_auto_start_game)
            {
                ;判断模式是否匹配
                if(lol_api.get_room(&room) && room != g_room_type)
                {
                    logger.warn('房间模式不匹配')
                    if(g_is_auto_create_room)
                    {
                        logger.in('创建房间')
                        que_id := g_room_type
                        rtn := lol_api.create_room(que_id)
                        logger.out(rtn)
                    }
                }
                else
                {
                    lol_api.search_queue()
                }
            }
        }
        case 'Matchmaking':
        {
            ;匹配中
            if(lol_api.get_status(&status))
                logger.info(status)
        }
        case 'InProgress':
        {

        }
        case 'ChampSelect':
        {

        }
        case 'PreEndOfGame':
        {

        }
        case 'WaitingForStats':
        {

        }
        case 'ReadyCheck':
        {
            ;找到对局
            if(g_is_auto_receive_game)
            {
                rtn := lol_api.accept_a_match()
                if(!rtn)
                    logger.err('接收对局失败')
                else
                    logger.info('接受对局成功')
            }
        }
        case 'EndOfGame':
        {
            if(g_is_auto_next_game)
            {
                logger.info('自动开始下一局')
                lol_api.auto_next_game()
            }
        }
        case 'Reconnect':
        {

        }
        default:
            logger.warn('不处理该状态:' status)
    }
}

loadconfig(&config, json_path)
{
    outputvar := FileRead(json_path)
    config := JSON.parse(outputvar)
}
;保存配置函数
saveconfig(config, json_path)
{
    str := JSON.stringify(config, 4)
    FileDelete(json_path)
    FileAppend(str, json_path, 'UTF-8')
}

class Lcu
{
    __New()
    {
        this.local_port := 2999
        this.base_url := 'https://127.0.0.1:'
        if(!this.get_cmd_info())
        {
            MsgBox('获取状态失败，请先打开客户端，然后管理员模式运行!!!')
            ExitApp
        }

        this.normal_modes := 
        {
            0: "5V5 训练模式", ; 这是自定义的编号
            420: "排位赛 单排/双排",
            430: "匹配模式 自选",
            440: "排位赛 灵活排位",
            450: "极地大乱斗 嚎哭深渊",
            830: "人机 召唤师峡谷 入门",
            840: "人机 召唤师峡谷 新手",
            850: "人机 召唤师峡谷 一般",
            1090: "云顶之弈 匹配",
            1100: "云顶之弈 排位",
            2000: "新手教程 一",
            2010: "新手教程 二",
            2020: "新手教程 三"
        }

    }
    ;游戏状态字符串
    get_game_status_string(status)
    {
        mp := Map(
            "Error", '获取错误', 
            "None", '游戏大厅',
            "Lobby", '房间内',
            "Matchmaking", '匹配中',
            "ReadyCheck", '找到对局',
            "ChampSelect", '选英雄中',
            "InProgress", '游戏中',
            "PreEndOfGame", '游戏即将结束',
            "WaitingForStats", '等待结算页面',
            "EndOfGame", '游戏结束',
            "Reconnect", '等待重新连接'
        )
        if(mp.Has(status))
            return mp[status]
        else
            return 'Error'
    }

    ;获取命令参数
    get_cmd_info()
    {
        cmd_result := ReadProcessStdOut('cmd /c wmic PROCESS WHERE name="LeagueClientUx.exe" GET commandline')
        if(RegExMatch(cmd_result, '"--remoting-auth-token=(.*?)"', &sub_pt1)
            && RegExMatch(cmd_result, '"--app-port=(.*?)"', &sub_pt2)
            && RegExMatch(cmd_result, '"--app-pid=(.*?)"', &sub_pt3))
        {
            this.token := sub_pt1[1]
            this.port := sub_pt2[1]
            this.app_id := sub_pt3[1]
            this.auth  := StringToBase64("riot:" this.token)
        }
        else
            return false
        return true
    }
    ;创建房间
    create_room(que_id := 1090)
    {
        ;/lol-lobby/v2/lobby 作者：Marioㄹ https://www.bilibili.com/read/cv6477040/ 出处：bilibili
        rtn := this.request('POST', '/lol-lobby/v2/lobby',, JSON.stringify({queueId : que_id}))
        return rtn
    }
    ;获取房间
    get_room(&room)
    {
        room := ''
        rtn := this.request('GET', '/lol-lobby/v2/lobby', &text)
        if(rtn)
        {
            try
            {
                js := JSON.parse(text)
                if(js.Has('gameConfig') && js['gameConfig'].Has('queueId'))
                    room := js['gameConfig']['queueId']
            }
            catch as e
            {
                rtn := false
                logger.err(e.Message)
            }
        }
        return rtn
    }
    ;创建5v5房间
    create_room_5v5(lobbyName := "test_lobby", teamSize := 5)
    {
        post_obj := 
        {
            customGameLobby: 
            {
                configuration: 
                {
                    gameMode: "PRACTICETOOL",
                    gameMutator: "",
                    gameServerRegion: "",
                    mapId: 11,
                    mutators: 
                    {
                        id: 1
                    },
                    spectatorPolicy: "AllAllowed",
                    teamSize: teamSize
                },
                lobbyName: lobbyName,
                lobbyPassword: 'None'
            },
            isCustom: True
        }
        rtn := this.request('POST', '/lol-lobby/v2/lobby',, JSON.stringify(post_obj))
        return rtn
    }
    ;获取天赋
    gain_rune_talent(&talent)
    {
        rtn := this.request('GET', '/lol-perks/v1/currentpage', &text)
        if(rtn)
        {
            try
            {
                talent := JSON.parse(text)
            }
            catch as e
            {
                rtn := false
                logger.err(e.Message)
            }
        }
        return rtn
    }
    ;获取状态
    get_status(&status)
    {
        rtn := this.request('GET', '/lol-lobby/v2/lobby/matchmaking/search-state', &text)
        if(rtn)
        {
            try
            {
                js := JSON.parse(text)
                status := js['searchState']
            }
            catch as e
            {
                rtn := false
                logger.err(e.Message)
            }
        }
        return rtn
    }
    ;获取客户端状态,比如 游戏中,大厅中
    get_game_status(&status)
    {
        if(this.request('GET', '/lol-gameflow/v1/gameflow-phase', &status := ''))
        {
            if(RegExMatch(status, '"(.*)"', &sub_pt))
                status := sub_pt[1]
            else
                return false
        }
        else
            return false
        return true
    }
    ;接受对局
    accept_a_match()
    {
        rtn := this.request('POST', '/lol-matchmaking/v1/ready-check/accept')
        return rtn
    }
    ;自动开始下一句对局
    auto_next_game()
    {
        rtn := this.request('POST', '/lol-lobby/v2/play-again')
        return rtn
    }
    ;排队
    search_queue()
    {
        rtn := this.request('POST', '/lol-lobby/v2/lobby/matchmaking/search')
        return rtn
    }
    ;发送请求
    request(interface, api, &text := false, post_data := '',port := this.port)
    {
        rtn := true
        try
        {
            api := this.base_url port api
            whq := WinHttpRequest()
            whq.Option[4] := 13056
            whq.Open(interface, api, true)
            whq.SetRequestHeader('Content-Type', 'application/json')
            whq.SetRequestHeader('Accept', 'application/json')
            whq.SetRequestHeader('Authorization', 'Basic ' this.auth)
            whq.Send(post_data)
            whq.WaitForResponse()
            if(!IsSet(text) || (IsSet(text) && text != false))
            {
                body := whq.ResponseBody
                text := StrGet(body, 'UTF-8')
                logger.info('original:' text)
            }
        }
        catch as e
        {
            rtn := false
            logger.err(e)
        }
        return rtn
    }
}


StringToBase64(String, Encoding := "UTF-8")
{
	static CRYPT_STRING_BASE64 := 0x00000001
	static CRYPT_STRING_NOCRLF := 0x40000000

	Binary := Buffer(StrPut(String, Encoding))
	StrPut(String, Binary, Encoding)
	if !(DllCall("crypt32\CryptBinaryToStringW", "Ptr", Binary, "UInt", Binary.Size, "UInt", (CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF), "Ptr", 0, "UInt*", &Size := 0))
		throw Error("CryptBinaryToStringW failed", -1)

	Base64 := Buffer(Size << 1, 0)
	if !(DllCall("crypt32\CryptBinaryToStringW", "Ptr", Binary, "UInt", Binary.Size, "UInt", (CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF), "Ptr", Base64, "UInt*", Size))
		throw Error("CryptBinaryToStringW failed", -1)

	return StrGet(Base64)
}

ReadProcessStdOut(cmd, stdin := "", encoding := "cp0") {
    sa := Buffer(24)
    NumPut("uint", sa.Size, sa)
    NumPut("ptr", 0, "uint", 1, sa, 8)

    if !DllCall("CreatePipe", "ptr*", &hReadPipeOut := 0, "ptr*", &hWritePipeOut := 0, "ptr", sa, "uint", 0)
        throw OSError()
    DllCall("SetHandleInformation", "ptr", hReadPipeOut, "uint", 1, "uint", 0)

    si := Buffer(104, 0)
    NumPut("uint", si.Size, si)
    NumPut("uint", 0x101, si, 60)
    NumPut("ptr", hWritePipeOut, si, 88)

    if stdin !== "" {
        if !DllCall("CreatePipe", "ptr*", &hReadPipeIn := 0, "ptr*", &hWritePipeIn := 0, "ptr", sa, "uint", 0)
            throw OSError()
        DllCall("SetHandleInformation", "ptr", hWritePipeIn, "uint", 1, "uint", 0)
        NumPut("ptr", hReadPipeIn, si, 80)
    }

    if !DllCall("CreateProcessW", "ptr", 0, "str", cmd, "ptr", 0, "ptr", 0, "int", true, "uint", 0, "ptr", 0, "ptr", 0, "ptr", si, "ptr", pi := Buffer(24)) {
        DllCall("CloseHandle", "ptr", hWritePipeOut)
        DllCall("CloseHandle", "ptr", hReadPipeOut)
        throw OSError()
    }
    DllCall("CloseHandle", "ptr", NumGet(pi, "ptr"))
    DllCall("CloseHandle", "ptr", NumGet(pi, 8, "ptr"))
    DllCall("CloseHandle", "ptr", hWritePipeOut)

    if stdin !== "" {
        DllCall("CloseHandle", "ptr", hReadPipeIn)
        if !DllCall("WriteFile", "ptr", hWritePipeIn, "astr", stdin, "uint", StrPut(stdin, "cp0") - 1, "uint*", &lpNumberOfBytesWritten := 0, "ptr", 0){
            DllCall("CloseHandle", "ptr", hWritePipeIn)
            throw OSError()
        }
        DllCall("CloseHandle", "ptr", hWritePipeIn)
    }

    stdout := ""
    while DllCall("ReadFile", "ptr", hReadPipeOut, "ptr", buf := Buffer(4096), "uint", buf.Size, "uint*", &lpNumberOfBytesRead := 0, "ptr", 0) && lpNumberOfBytesRead
        stdout .= StrGet(buf, lpNumberOfBytesRead, encoding)
    DllCall("CloseHandle", "ptr", hReadPipeOut)

    return stdout
}