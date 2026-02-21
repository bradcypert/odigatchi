package odigatchi

import "vendor:sdl2"
import "vendor:sdl2/image"
import "vendor:sdl2/mixer"
import "vendor:sdl2/ttf"
import "core:math"
import "core:c"

WINDOW_WIDTH :: 320
WINDOW_HEIGHT :: 400

get_window_flags :: proc() -> sdl2.WindowFlags {
    return sdl2.WindowFlags(sdl2.WINDOW_OPENGL | sdl2.WINDOW_BORDERLESS | sdl2.WINDOW_ALWAYS_ON_TOP)
}

get_renderer_flags :: proc() -> sdl2.RendererFlags {
    return sdl2.RendererFlags(sdl2.RENDERER_ACCELERATED | sdl2.RENDERER_PRESENTVSYNC)
}

get_window_color :: proc() -> sdl2.Color { return sdl2.Color{22, 33, 62, 230} }
get_accent_color :: proc() -> sdl2.Color { return sdl2.Color{233, 69, 96, 255} }
get_secondary_color :: proc() -> sdl2.Color { return sdl2.Color{15, 52, 96, 255} }
get_text_color :: proc() -> sdl2.Color { return sdl2.Color{234, 234, 234, 255} }
get_button_hover_color :: proc() -> sdl2.Color { return sdl2.Color{255, 107, 107, 255} }
get_success_color :: proc() -> sdl2.Color { return sdl2.Color{74, 222, 128, 255} }
get_warning_color :: proc() -> sdl2.Color { return sdl2.Color{251, 191, 36, 255} }

State :: enum {
    Idle,
    Eating,
    Playing,
    Talking,
    Sad,
}

Pet :: struct {
    hunger: int,
    happiness: int,
    energy: int,
    state: State,
    anim_timer: f32,
    action_cooldown: f32,
}

Button :: struct {
    x, y: f32,
    width, height: f32,
    hovered: bool,
    text: cstring,
}

ContextMenuItem :: struct {
    x, y: f32,
    width, height: f32,
    text: cstring,
    hovered: bool,
}

App :: struct {
    window: ^sdl2.Window,
    renderer: ^sdl2.Renderer,
    font: ^ttf.Font,
    running: bool,
    dragging: bool,
    drag_offset_x: i32,
    drag_offset_y: i32,
    show_context_menu: bool,
    menu_items: []ContextMenuItem,
    buttons: [3]Button,
    pet: Pet,
    time: f32,
}

init_app :: proc() -> ^App {
    app := new(App)
    app.running = true
    app.show_context_menu = false
    app.pet = Pet{hunger = 80, happiness = 80, energy = 80, state = .Idle, anim_timer = 0, action_cooldown = 0}
    app.time = 0

    if sdl2.Init(sdl2.INIT_VIDEO | sdl2.INIT_AUDIO) != 0 {
        return nil
    }

    if ttf.Init() != 0 {
        return nil
    }

    app.window = sdl2.CreateWindow(
        "Odigatchi",
        sdl2.WINDOWPOS_CENTERED,
        sdl2.WINDOWPOS_CENTERED,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        get_window_flags(),
    )
    if app.window == nil {
        return nil
    }

    app.renderer = sdl2.CreateRenderer(app.window, -1, get_renderer_flags())
    if app.renderer == nil {
        return nil
    }

    sdl2.SetRenderDrawBlendMode(app.renderer, sdl2.BlendMode.BLEND)

    app.font = ttf.OpenFont("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    if app.font == nil {
        app.font = ttf.OpenFont("/System/Library/Fonts/Helvetica.ttc", 14)
    }

    app.buttons = [3]Button{
        Button{x = 20, y = 330, width = 80, height = 36, text = "Feed", hovered = false},
        Button{x = 120, y = 330, width = 80, height = 36, text = "Play", hovered = false},
        Button{x = 220, y = 330, width = 80, height = 36, text = "Talk", hovered = false},
    }

    app.menu_items = []ContextMenuItem{
        ContextMenuItem{x = 50, y = 80, width = 120, height = 28, text = "Feed", hovered = false},
        ContextMenuItem{x = 50, y = 110, width = 120, height = 28, text = "Play", hovered = false},
        ContextMenuItem{x = 50, y = 140, width = 120, height = 28, text = "Talk", hovered = false},
        ContextMenuItem{x = 50, y = 175, width = 120, height = 28, text = "About", hovered = false},
        ContextMenuItem{x = 50, y = 210, width = 120, height = 28, text = "Close", hovered = false},
    }

    return app
}

feed_pet :: proc(app: ^App) {
    app.pet.hunger = min(100, app.pet.hunger + 20)
    app.pet.state = .Eating
    app.pet.anim_timer = 1.5
    app.pet.action_cooldown = 2.0
    app.show_context_menu = false
}

play_pet :: proc(app: ^App) {
    app.pet.happiness = min(100, app.pet.happiness + 20)
    app.pet.state = .Playing
    app.pet.anim_timer = 2.0
    app.pet.action_cooldown = 2.0
    app.show_context_menu = false
}

talk_pet :: proc(app: ^App) {
    app.pet.happiness = min(100, app.pet.happiness + 10)
    app.pet.state = .Talking
    app.pet.anim_timer = 1.5
    app.pet.action_cooldown = 2.0
    app.show_context_menu = false
}

show_about :: proc(app: ^App) {
    app.show_context_menu = false
}

update_pet :: proc(app: ^App, dt: f32) {
    app.time += dt

    if app.pet.action_cooldown > 0 {
        app.pet.action_cooldown -= dt
    } else if app.pet.state != .Idle {
        app.pet.state = .Idle
    }

    if app.pet.state == .Idle {
        app.pet.anim_timer += dt
        if app.pet.hunger < 30 || app.pet.happiness < 30 {
            app.pet.state = .Sad
        }
    }

    app.pet.hunger = max(0, app.pet.hunger - 1)
    app.pet.happiness = max(0, app.pet.happiness - 1)
    app.pet.energy = min(100, app.pet.energy + 1)
}

render :: proc(app: ^App) {
    sdl2.SetRenderDrawColor(app.renderer, 0, 0, 0, 0)
    sdl2.RenderClear(app.renderer)

    render_window_background(app)
    render_title_bar(app)
    render_pet(app)
    render_status_bars(app)
    render_buttons(app)

    if app.show_context_menu {
        render_context_menu(app)
    }

    sdl2.RenderPresent(app.renderer)
}

render_window_background :: proc(app: ^App) {
    rect := sdl2.Rect{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}
    col := get_window_color()
    sdl2.SetRenderDrawColor(app.renderer, col.r, col.g, col.b, col.a)
    sdl2.RenderFillRect(app.renderer, &rect)
}

render_title_bar :: proc(app: ^App) {
    rect := sdl2.Rect{0, 0, WINDOW_WIDTH, 40}
    col := get_secondary_color()
    sdl2.SetRenderDrawColor(app.renderer, col.r, col.g, col.b, 255)
    sdl2.RenderFillRect(app.renderer, &rect)

    if app.font != nil {
        surface := ttf.RenderText_Blended(app.font, "Odigatchi v1.0", get_text_color())
        if surface != nil {
            texture := sdl2.CreateTextureFromSurface(app.renderer, surface)
            tex_w: i32 = 0
            tex_h: i32 = 0
            sdl2.QueryTexture(texture, nil, nil, &tex_w, &tex_h)
            dst := sdl2.Rect{10, 10, tex_w, tex_h}
            sdl2.RenderCopy(app.renderer, texture, nil, &dst)
            sdl2.DestroyTexture(texture)
            sdl2.FreeSurface(surface)
        }
    }

    close_rect := sdl2.Rect{WINDOW_WIDTH - 30, 8, 22, 24}
    mouse_x, mouse_y: i32
    sdl2.GetMouseState(&mouse_x, &mouse_y)
    
    window_x, window_y: i32
    sdl2.GetWindowPosition(app.window, &window_x, &window_y)
    rel_x := mouse_x - window_x
    rel_y := mouse_y - window_y
    
    in_close := rel_x >= close_rect.x && rel_x < close_rect.x + close_rect.w && 
                rel_y >= close_rect.y && rel_y < close_rect.y + close_rect.h
    
    if in_close {
        sdl2.SetRenderDrawColor(app.renderer, 200, 50, 50, 255)
    } else {
        col = get_accent_color()
        sdl2.SetRenderDrawColor(app.renderer, col.r, col.g, col.b, 255)
    }
    sdl2.RenderFillRect(app.renderer, &close_rect)

    if app.font != nil {
        surface := ttf.RenderText_Blended(app.font, "X", get_text_color())
        if surface != nil {
            texture := sdl2.CreateTextureFromSurface(app.renderer, surface)
            tex_w: i32 = 0
            tex_h: i32 = 0
            sdl2.QueryTexture(texture, nil, nil, &tex_w, &tex_h)
            dst := sdl2.Rect{close_rect.x + 6, close_rect.y + 4, tex_w, tex_h}
            sdl2.RenderCopy(app.renderer, texture, nil, &dst)
            sdl2.DestroyTexture(texture)
            sdl2.FreeSurface(surface)
        }
    }
}

render_pet :: proc(app: ^App) {
    center_x: i32 = WINDOW_WIDTH / 2
    center_y: i32 = 180

    bounce_offset: f32 = 0

    anim_phase := app.pet.anim_timer * 3.0

    switch app.pet.state {
    case .Idle:
        bounce_offset = math.sin(anim_phase) * 5
    case .Eating:
        bounce_offset = math.sin(anim_phase * 2) * 3
    case .Playing:
        bounce_offset = math.sin(anim_phase * 3) * 8
    case .Talking:
        bounce_offset = math.sin(anim_phase * 1.5) * 4
    case .Sad:
        bounce_offset = math.sin(anim_phase * 0.5) * 3
    }

    pet_y := center_y + i32(bounce_offset)

    body_color := sdl2.Color{147, 197, 75, 255}
    if app.pet.state == .Sad {
        body_color = sdl2.Color{100, 150, 100, 255}
    }

    sdl2.SetRenderDrawColor(app.renderer, body_color.r, body_color.g, body_color.b, 255)
    body_rect := sdl2.Rect{center_x - 30, pet_y - 35, 60, 55}
    sdl2.RenderFillRect(app.renderer, &body_rect)

    eye_y := pet_y - 20
    sdl2.SetRenderDrawColor(app.renderer, 30, 30, 30, 255)
    left_eye := sdl2.Rect{center_x - 15, eye_y - 8, 10, 12}
    right_eye := sdl2.Rect{center_x + 5, eye_y - 8, 10, 12}
    sdl2.RenderFillRect(app.renderer, &left_eye)
    sdl2.RenderFillRect(app.renderer, &right_eye)

    sdl2.SetRenderDrawColor(app.renderer, 255, 255, 255, 255)
    left_pupil := sdl2.Rect{center_x - 12, eye_y - 5, 4, 4}
    right_pupil := sdl2.Rect{center_x + 8, eye_y - 5, 4, 4}
    sdl2.RenderFillRect(app.renderer, &left_pupil)
    sdl2.RenderFillRect(app.renderer, &right_pupil)

    mouth_y := pet_y + 5
    sdl2.SetRenderDrawColor(app.renderer, 30, 30, 30, 255)
    
    if app.pet.state == .Eating {
        mouth_rect := sdl2.Rect{center_x - 8, mouth_y, 16, 10}
        sdl2.RenderFillRect(app.renderer, &mouth_rect)
    } else if app.pet.state == .Talking {
        if i32(anim_phase) % 2 == 0 {
            mouth_rect := sdl2.Rect{center_x - 8, mouth_y, 16, 5}
            sdl2.RenderFillRect(app.renderer, &mouth_rect)
        } else {
            mouth_rect := sdl2.Rect{center_x - 8, mouth_y, 16, 10}
            sdl2.RenderFillRect(app.renderer, &mouth_rect)
        }
    } else {
        mouth_rect := sdl2.Rect{center_x - 8, mouth_y, 16, 3}
        sdl2.RenderFillRect(app.renderer, &mouth_rect)
    }

    foot_color := sdl2.Color{body_color.r - 30, body_color.g - 30, body_color.b - 30, 255}
    sdl2.SetRenderDrawColor(app.renderer, foot_color.r, foot_color.g, foot_color.b, 255)
    left_foot := sdl2.Rect{center_x - 25, pet_y + 20, 15, 10}
    right_foot := sdl2.Rect{center_x + 10, pet_y + 20, 15, 10}
    sdl2.RenderFillRect(app.renderer, &left_foot)
    sdl2.RenderFillRect(app.renderer, &right_foot)

    if app.pet.state == .Playing || app.pet.state == .Talking {
        if i32(anim_phase) % 2 == 0 {
            heart_color := get_accent_color()
            sdl2.SetRenderDrawColor(app.renderer, heart_color.r, heart_color.g, heart_color.b, 255)
            heart1 := sdl2.Rect{center_x - 45, pet_y - 30, 10, 10}
            heart2 := sdl2.Rect{center_x + 35, pet_y - 25, 10, 10}
            sdl2.RenderFillRect(app.renderer, &heart1)
            sdl2.RenderFillRect(app.renderer, &heart2)
        }
    }

    if app.pet.state == .Eating {
        food_color := get_warning_color()
        sdl2.SetRenderDrawColor(app.renderer, food_color.r, food_color.g, food_color.b, 255)
        food := sdl2.Rect{center_x + 20, pet_y - 10, 15, 15}
        sdl2.RenderFillRect(app.renderer, &food)
    }
}

render_status_bars :: proc(app: ^App) {
    bar_y: i32 = 270
    bar_width: i32 = 200
    bar_height: i32 = 16

    if app.font != nil {
        label := ttf.RenderText_Blended(app.font, "Hunger", get_text_color())
        if label != nil {
            texture := sdl2.CreateTextureFromSurface(app.renderer, label)
            dst := sdl2.Rect{20, bar_y, 50, 14}
            sdl2.RenderCopy(app.renderer, texture, nil, &dst)
            sdl2.DestroyTexture(texture)
            sdl2.FreeSurface(label)
        }
    }

    bg_color := sdl2.Color{50, 50, 50, 255}
    bg_rect := sdl2.Rect{75, bar_y, bar_width, bar_height}
    sdl2.SetRenderDrawColor(app.renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a)
    sdl2.RenderFillRect(app.renderer, &bg_rect)

    fill_width := i32(f32(bar_width) * f32(app.pet.hunger) / 100.0)
    if fill_width > 0 {
        fill_color := get_stat_color(app.pet.hunger)
        fill_rect := sdl2.Rect{75, bar_y, fill_width, bar_height}
        sdl2.SetRenderDrawColor(app.renderer, fill_color.r, fill_color.g, fill_color.b, 255)
        sdl2.RenderFillRect(app.renderer, &fill_rect)
    }

    bar_y += 25

    if app.font != nil {
        label := ttf.RenderText_Blended(app.font, "Happy", get_text_color())
        if label != nil {
            texture := sdl2.CreateTextureFromSurface(app.renderer, label)
            dst := sdl2.Rect{20, bar_y, 50, 14}
            sdl2.RenderCopy(app.renderer, texture, nil, &dst)
            sdl2.DestroyTexture(texture)
            sdl2.FreeSurface(label)
        }
    }

    bg_rect = sdl2.Rect{75, bar_y, bar_width, bar_height}
    sdl2.SetRenderDrawColor(app.renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a)
    sdl2.RenderFillRect(app.renderer, &bg_rect)

    fill_width = i32(f32(bar_width) * f32(app.pet.happiness) / 100.0)
    if fill_width > 0 {
        fill_color := get_stat_color(app.pet.happiness)
        fill_rect := sdl2.Rect{75, bar_y, fill_width, bar_height}
        sdl2.SetRenderDrawColor(app.renderer, fill_color.r, fill_color.g, fill_color.b, 255)
        sdl2.RenderFillRect(app.renderer, &fill_rect)
    }

    bar_y += 25

    if app.font != nil {
        label := ttf.RenderText_Blended(app.font, "Energy", get_text_color())
        if label != nil {
            texture := sdl2.CreateTextureFromSurface(app.renderer, label)
            dst := sdl2.Rect{20, bar_y, 50, 14}
            sdl2.RenderCopy(app.renderer, texture, nil, &dst)
            sdl2.DestroyTexture(texture)
            sdl2.FreeSurface(label)
        }
    }

    bg_rect = sdl2.Rect{75, bar_y, bar_width, bar_height}
    sdl2.SetRenderDrawColor(app.renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a)
    sdl2.RenderFillRect(app.renderer, &bg_rect)

    fill_width = i32(f32(bar_width) * f32(app.pet.energy) / 100.0)
    if fill_width > 0 {
        fill_rect := sdl2.Rect{75, bar_y, fill_width, bar_height}
        sdl2.SetRenderDrawColor(app.renderer, 100, 150, 255, 255)
        sdl2.RenderFillRect(app.renderer, &fill_rect)
    }
}

get_stat_color :: proc(value: int) -> sdl2.Color {
    if value > 60 {
        return get_success_color()
    } else if value > 30 {
        return get_warning_color()
    } else {
        return get_accent_color()
    }
}

render_buttons :: proc(app: ^App) {
    mouse_x, mouse_y: i32
    sdl2.GetMouseState(&mouse_x, &mouse_y)
    
    window_x, window_y: i32
    sdl2.GetWindowPosition(app.window, &window_x, &window_y)
    rel_x := mouse_x - window_x
    rel_y := mouse_y - window_y

    for &btn in app.buttons {
        btn.hovered = rel_x >= i32(btn.x) && rel_x < i32(btn.x + btn.width) &&
                      rel_y >= i32(btn.y) && rel_y < i32(btn.y + btn.height)

        bg_color := get_secondary_color()
        if btn.hovered {
            bg_color = get_button_hover_color()
        }

        rect := sdl2.Rect{i32(btn.x), i32(btn.y), i32(btn.width), i32(btn.height)}
        sdl2.SetRenderDrawColor(app.renderer, bg_color.r, bg_color.g, bg_color.b, 255)
        sdl2.RenderFillRect(app.renderer, &rect)

        if app.font != nil {
            surface := ttf.RenderText_Blended(app.font, btn.text, get_text_color())
            if surface != nil {
                texture := sdl2.CreateTextureFromSurface(app.renderer, surface)
                tex_w: i32 = 0
                tex_h: i32 = 0
                sdl2.QueryTexture(texture, nil, nil, &tex_w, &tex_h)
                dst := sdl2.Rect{i32(btn.x) + (i32(btn.width) - tex_w) / 2, 
                                i32(btn.y) + (i32(btn.height) - tex_h) / 2, 
                                tex_w, tex_h}
                sdl2.RenderCopy(app.renderer, texture, nil, &dst)
                sdl2.DestroyTexture(texture)
                sdl2.FreeSurface(surface)
            }
        }
    }
}

render_context_menu :: proc(app: ^App) {
    mouse_x, mouse_y: i32
    sdl2.GetMouseState(&mouse_x, &mouse_y)
    
    window_x, window_y: i32
    sdl2.GetWindowPosition(app.window, &window_x, &window_y)
    rel_x := mouse_x - window_x
    rel_y := mouse_y - window_y

    menu_bg := sdl2.Rect{40, 70, 150, 180}
    col := get_secondary_color()
    sdl2.SetRenderDrawColor(app.renderer, col.r, col.g, col.b, 255)
    sdl2.RenderFillRect(app.renderer, &menu_bg)

    col = get_accent_color()
    sdl2.SetRenderDrawColor(app.renderer, col.r, col.g, col.b, 255)
    sdl2.RenderDrawRect(app.renderer, &menu_bg)

    for &item in app.menu_items {
        item.hovered = rel_x >= i32(item.x) && rel_x < i32(item.x + item.width) &&
                        rel_y >= i32(item.y) && rel_y < i32(item.y + item.height)

        if item.hovered {
            bg := sdl2.Rect{i32(item.x), i32(item.y), i32(item.width), i32(item.height)}
            col = get_accent_color()
            sdl2.SetRenderDrawColor(app.renderer, col.r, col.g, col.b, 150)
            sdl2.RenderFillRect(app.renderer, &bg)
        }

        if app.font != nil {
            surface := ttf.RenderText_Blended(app.font, item.text, get_text_color())
            if surface != nil {
                texture := sdl2.CreateTextureFromSurface(app.renderer, surface)
                tex_w: i32 = 0
                tex_h: i32 = 0
                sdl2.QueryTexture(texture, nil, nil, &tex_w, &tex_h)
                dst := sdl2.Rect{i32(item.x) + 10, i32(item.y) + 6, tex_w, tex_h}
                sdl2.RenderCopy(app.renderer, texture, nil, &dst)
                sdl2.DestroyTexture(texture)
                sdl2.FreeSurface(surface)
            }
        }
    }
}

handle_event :: proc(app: ^App, event: ^sdl2.Event) -> bool {
    #partial switch event.type {
    case .QUIT:
        app.running = false
        return true

    case .MOUSEBUTTONDOWN:
        mouse_x := event.button.x
        mouse_y := event.button.y

        if event.button.button == sdl2.BUTTON_LEFT {
            if mouse_y < 40 && mouse_x < WINDOW_WIDTH - 30 {
                app.dragging = true
                app.drag_offset_x = mouse_x
                app.drag_offset_y = mouse_y
                return true
            }

            if mouse_x >= WINDOW_WIDTH - 30 && mouse_x < WINDOW_WIDTH - 8 && mouse_y >= 8 && mouse_y < 32 {
                app.running = false
                return true
            }

            for &btn in app.buttons {
                if mouse_x >= i32(btn.x) && mouse_x < i32(btn.x + btn.width) &&
                   mouse_y >= i32(btn.y) && mouse_y < i32(btn.y + btn.height) {
                    if app.pet.action_cooldown <= 0 {
                        if &btn == &app.buttons[0] {
                            feed_pet(app)
                        } else if &btn == &app.buttons[1] {
                            play_pet(app)
                        } else if &btn == &app.buttons[2] {
                            talk_pet(app)
                        }
                    }
                    return true
                }
            }
        }

        if event.button.button == sdl2.BUTTON_RIGHT {
            app.show_context_menu = !app.show_context_menu
            return true
        }

    case .MOUSEBUTTONUP:
        if app.dragging {
            app.dragging = false
            return true
        }

        if app.show_context_menu {
            mouse_x := event.button.x
            mouse_y := event.button.y

            menu_clicked := -1
            for i := 0; i < len(app.menu_items); i += 1 {
                item := app.menu_items[i]
                if mouse_x >= i32(item.x) && mouse_x < i32(item.x + item.width) &&
                   mouse_y >= i32(item.y) && mouse_y < i32(item.y + item.height) {
                    menu_clicked = i
                    break
                }
            }

            if menu_clicked >= 0 {
                switch menu_clicked {
                case 0:
                    feed_pet(app)
                case 1:
                    play_pet(app)
                case 2:
                    talk_pet(app)
                case 3:
                    show_about(app)
                case 4:
                    app.running = false
                }
                return true
            }

            menu_bounds := sdl2.Rect{40, 70, 150, 180}
            if !(mouse_x >= menu_bounds.x && mouse_x < menu_bounds.x + menu_bounds.w &&
                 mouse_y >= menu_bounds.y && mouse_y < menu_bounds.y + menu_bounds.h) {
                app.show_context_menu = false
            }
        }

    case .MOUSEMOTION:
        if app.dragging {
            x := event.motion.x - app.drag_offset_x
            y := event.motion.y - app.drag_offset_y
            
            win_x, win_y: i32
            sdl2.GetWindowPosition(app.window, &win_x, &win_y)
            sdl2.SetWindowPosition(app.window, win_x + x, win_y + y)
            return true
        }
    }

    return false
}

main :: proc() {
    app := init_app()
    if app == nil {
        return
    }
    defer {
        if app.font != nil {
            ttf.CloseFont(app.font)
        }
        if app.renderer != nil {
            sdl2.DestroyRenderer(app.renderer)
        }
        if app.window != nil {
            sdl2.DestroyWindow(app.window)
        }
        ttf.Quit()
        sdl2.Quit()
    }

    last_time := f32(sdl2.GetTicks()) / 1000.0

    for app.running {
        event: sdl2.Event
        for sdl2.PollEvent(&event) {
            handle_event(app, &event)
        }

        current_time := f32(sdl2.GetTicks()) / 1000.0
        dt := current_time - last_time
        last_time = current_time

        update_pet(app, dt)
        render(app)

        sdl2.Delay(16)
    }
}
