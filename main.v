import term
import readline
import time
import rand

//
// CONSTANTS
//

const c_cell_empty = 0;
const c_cell_food  = 1;
const c_cell_snake = 2;
const c_cell_spawn = 3;
const c_cell_dead  = 4;

const keyboard_w = 119;
const keyboard_s = 115;
const keyboard_a = 97;
const keyboard_d = 100;
//
// BASE TYPES
//

enum Direction
{
  left right
  up down
}

struct Vec2 {
  mut:
    x int
    y int
}

struct Line {
  mut:
    begin      Vec2
    grow_vec   Direction
    length     int
}

//
// ARENA
//

enum Cell {
  empty
  food
  snake
  nest
  death
}

struct Arena {
  mut:
    size Vec2
    grid [][]Cell
    food []Vec2
}

//
// SNAKE
//


struct Snake {
  mut:  
    length      u8
    direction   Direction
    origin      Vec2
    parts       []Line
    blocked     bool
    dead        bool
}

//
// TODO: 
// + dynamic updating
// + bound checking
// + ui

fn main() {

  mut exit := false

  for !exit {

    mut term_size := Vec2{}
    term_size.x , term_size.y = term.get_terminal_size()

    half_size := Vec2 {
      x: term_size.x / 2
      y: term_size.y / 2
    }


    smaller := f32_min( half_size.x, half_size.y)

    arena_size := Vec2 {
      x: int(smaller)
      y: int(smaller)
    }

    padding := Vec2 {
      x: (term_size.x - int(smaller)*2) / 2
      y: (term_size.y - int(smaller)*2) / 2
    }


    size  := arena_size //arena_size
    mut arena := Arena.new(size)

    mut direction := Direction.down
    mut snake := Snake.new( 
      Vec2 {
        size.x / 2,
        size.y / 4
      }, direction)

    snake.blocked = false
    mut ch := u8(0)

    for {

      spawn readstdin(mut &ch)

      term.clear()
      arena.clear()   

      match ch {
      keyboard_s {
        direction = Direction.down  
      }

      keyboard_w {
        direction = Direction.up
      }

      keyboard_d {
        direction = Direction.right
      }

      keyboard_a {
        direction = Direction.left
      }

      27 { 
        exit = true
        break
      }

      32 { 
        break 
      }

      else {}
    }

      if !snake.dead {
        snake.hunt(mut arena)
        snake.look_obstacles(size)
        if (snake.direction() != direction) 
        {
          snake.turn(direction)
          snake.blocked = false
        }
        snake.live()

        if !snake.blocked  {
          snake.move(arena.size) or {println(err)}
        }

        snake.snake_in_one_piece()

        snake.collider()

        arena.grow_food(1,snake)
        arena.imagine_snake(snake) or {println(err)}

        arena.draw(padding.y,padding.x,mut snake)

        for i:=snake.parts.len - 1; i >= 0; i--
        {
          /* println("node with pos [${i}] has len: ${snake.parts[i].length}"); */
        }

        if snake.blocked {
          /* println("block triggered") */
        }

        if !snake.within_arena(size) {
          snake.dead = true
          /* println("snake IS OUT") */
          //break
        }
        time.sleep( 1 * 100000000)
      }


      else {
        death_screen(term_size,snake,arena)
        time.sleep( 0.5 * 100000000)
      }
    }
  }
}

//
// FUNCTIONS & METHODS
//


// Cooroutine input function

fn readstdin (mut input &u8) {
  mut reader := readline.Readline{}
  
  reader.enable_raw_mode()
  input = reader.read_char() or { 27 }
  reader.disable_raw_mode()
}


// DIRECTIONS

fn (d Direction) reverse() Direction
{
  return match d {
    .right {Direction.left }
    .left  {Direction.right}
    .up    {Direction.down }
    .down  {Direction.up   }
  }
}

// ARENA


fn Arena.new(size Vec2) Arena
{
  return Arena {
    size: size
    grid: [][]Cell { 
      len: size.y, 
      init: []Cell { len: size.x, init: Cell.empty }
    }
  }
};

fn (mut a Arena) clear()
{
  for y:=0; y < a.size.y; y++ {
    for x:=0; x < a.size.x; x++ {
      a.grid[y][x] = Cell.empty
    }
  }
}

fn (mut a Arena) resize(newsize Vec2) {
   if newsize.y > a.size.y {
    for y := a.size.y; y < newsize.y; y++
    {
      a.grid << []Cell { len: newsize.x, init: Cell.empty }
    }
  }
  if newsize.x > a.size.x {

    for y := 0; y < a.size.y; y++ {
      a.grid[y] << []Cell {len: newsize.x - a.size.x, init: Cell.empty}
      for x := a.size.x; x < newsize.x; x++
      {
        a.grid[y][x] = Cell.empty
      }
    }
  }
  if (newsize.x < a.size.x)
  {
    for y:= 0; y < a.size.y; y++ {
      a.grid[y].delete_many(newsize.x, a.size.x - newsize.x)
      /* println(y) */
    }
  }
  if (newsize.y < a.size.y)
  {
    a.grid.delete_many(newsize.y, a.size.y - newsize.y)
  }
  a.size.x = newsize.x
  a.size.y = newsize.y
  a.size.x = newsize.x
}

fn (mut a Arena) draw(padding_x int, padding_y int,mut player Snake)
{
  mut pady   := "";
  mut padx   := "";
  mut topbar := "";
  mut botbar := "";

  for tb := 0; tb < (a.size.x + 1) * 2; tb++ {
    topbar += match tb {
      0  { "┌" }
      (a.size.x) * 2+1 {"┐"}
      else { "─" }
    }
  }

  for bb := 0; bb < (a.size.y + 1) * 2; bb++ {
    botbar += match bb {
      0  { "└" }
      (a.size.y) * 2+1 {"┘"}
      else { "─" }
    }
  }

  for py := 0; py < padding_y - 1; py++ {
    pady += '\n';
  }

  for px := 0; px < padding_y; px++ {
    padx += ' ';
  }
  print(pady)
  print(padx)
  score := player.score()
  println("${padx}score: ${score}")
  print(padx)
  println(topbar)
  for y:=0; y < a.size.y; y++ {
    print(padx)
 	  print("│")
    for x:=0; x < a.size.x; x++ {
      mut ch := match a.grid[y][x] {
        .empty { "  "}
        .food  { term.bright_green("▗▖") }
        .snake { "██"}
        .nest  { "~~"}
        .death { "xx"}
      }
      if Vec2 {x,y} in a.food {
        ch = term.bright_green("▗▖")
      }

      print(ch)
    }

 	  print("│")
    println("")
  }
  print(padx)
  println(botbar)
}

fn (mut a Arena) put(position Vec2, cell Cell) !
{
  within_x := position.x < a.size.x && position.x >= 0
  within_y := position.y < a.size.y && position.y >= 0

  if within_x && within_y
  {
    a.grid[position.y][position.x] = cell
  } 
  else 
  {
    error_msg := "failed to put point " + 
    "[ x: " + position.x.str() + 
    ", y: " + position.y.str() + " ],"+
    " overflows: "+ 
    "[ x: " + within_x.str() + 
    ", y: " + within_y.str() + "]" 
    error(error_msg);
  }
}

fn (mut a Arena) draw_line(l Line) !
{
  origin := l.begin

  for i:=0; i < l.length; i++
  {
    match l.grow_vec
    {
      .right { a.put(Vec2 { x: origin.x + i, y: origin.y}, Cell.snake)  
        or {error("failed to draw_line")} }

      .left  { a.put(Vec2 { x: origin.x - i, y: origin.y}, Cell.snake)  
        /* or {error(err)} }} */
        or {error("failed to draw_line")} }

      .up    { a.put(Vec2 { x: origin.x, y: origin.y - i}, Cell.snake)  
        /* or {error(err)} }} */
        or {error("failed to draw_line")} }

      .down  { a.put(Vec2 { x: origin.x, y: origin.y + i}, Cell.snake)  
        /* or {error(err)} }} */
        or {error("failed to draw_line")} }
    }
  }
}


fn (mut a Arena) imagine_snake(s Snake)!
{
  // read from end
  for p := s.parts.len - 1; p >= 0; p--
  {
    a.draw_line(s.parts[p]) or { return error("cant imagine snake") }
  }
}


fn (mut a Arena) grow_food(cap int, player Snake) {
  if a.food.len < cap {

    mut player_cells := []Vec2 {}
    s                := &player

    for i:=0; i < s.parts.len; i++ {
      for l:=0; l < s.parts[i].length; l++ {
        origin := s.parts[i].begin
        player_cells << match s.parts[i].grow_vec {
          .right { Vec2 { x: origin.x + l, y: origin.y}  }
          .left  { Vec2 { x: origin.x - l, y: origin.y} }
          .up    { Vec2 { x: origin.x, y: origin.y - l} }
          .down  { Vec2 { x: origin.x, y: origin.y + l} }
        }
      }
    }

    mut food_pos := Vec2  { 
      x: rand.int_in_range(1,a.size.x - 2) or { 3 }
      y: rand.int_in_range(1,a.size.y - 2) or { 6 }
    }

    for {
      if food_pos in player_cells {
        food_pos = Vec2  { 
          x: rand.int_in_range(1,a.size.x - 2) or { 3 }
          y: rand.int_in_range(1,a.size.y - 2) or { 6 }
        }
        continue
      }
      else {
        a.food << food_pos
        break
      }
    }

  }
}
//
// SNAKE
//

fn Snake.new(origin Vec2, way Direction) Snake
{
  return Snake {
      blocked: false
      length: u8(1)
      direction: way
      origin: origin
      parts: []Line { len: 1, init: Line {
        begin: origin
        length: 1
        grow_vec: way.reverse()
      }}
  }
}

fn (s Snake) direction() Direction {
  return s.parts[s.parts.len-1].grow_vec.reverse()
}

fn (mut s Snake) turn(way Direction)
{
  last := s.parts[s.parts.len - 1]

  if (way != last.grow_vec) {
    s.parts << Line {
      begin: last.begin
      grow_vec: way.reverse()
      length: u8(0)
    }
  }
}

fn (mut s Snake) rest() {
  if s.parts.len != 1 {
    
    mut first := &s.parts[0]
    mut last  := &s.parts[s.parts.len - 1]

    /* for p := s.parts.len - 1; p >= 0; p-- */
    /* { */
    /**/
    /* } */
        match last.grow_vec {
          .right { last.begin.x-- }
          .left  { last.begin.x++ }
          .up    { last.begin.y++ }
          .down  { last.begin.y-- }
        }
  }
}

fn (mut s Snake) live() {
  if s.parts.len != 1 {
    
    mut first := &s.parts[0]
    mut last  := &s.parts[s.parts.len - 1]

    /* for p := s.parts.len - 1; p >= 0; p-- */
    /* { */
    /**/
    /* } */
    if (!s.blocked)    {
      match last.grow_vec {
      .right { last.begin.x++ }
      .left  { last.begin.x-- }
      .up    { last.begin.y-- }
      .down  { last.begin.y++ }
    }

      last.length++
      first.length--
    }
    if first.length == 0 {
     
      /* last.length+=1 */
      s.parts.delete(0)
    }
  }
}

fn (mut s Snake) snake_in_one_piece()
{
  if s.parts.len != 1 {
    for p := s.parts.len - 1; p >= 0; p--
    {
      if (p - 1 >= 0)
      {
        mut before := &s.parts[p-1]
        now    := &s.parts[p]

        before.begin = match now.grow_vec {
          .right {  Vec2 {x: now.begin.x + now.length, y: now.begin.y }}
          .left  {  Vec2 {x: now.begin.x - now.length, y: now.begin.y }}
          .up    {  Vec2 {x: now.begin.x , y: now.begin.y - now.length}}
          .down  {  Vec2 {x: now.begin.x , y: now.begin.y + now.length}}
        }
      }
    }
  }
}

fn (s Snake) move(arena_bounds Vec2) ! {
 
  mut last := &s.parts[s.parts.len - 1]
  mut step := int(1)

  if (s.parts.len > 1) {
    step = 2
  }
   
  next := match last.grow_vec.reverse() {
    .right { Vec2 {x: last.begin.x + step, y: last.begin.y        } }
    .left  { Vec2 {x: last.begin.x - step, y: last.begin.y        } }
    .up    { Vec2 {x: last.begin.x       , y: last.begin.y - step } }
    .down  { Vec2 {x: last.begin.x       , y: last.begin.y + step } }
  }

  last.begin = next
 
}

fn (mut s Snake) look_obstacles(bounds Vec2) {
  last := s.parts[s.parts.len - 1]

  step := 1
  pad  := 1

  /* println("head before: [${last.begin.x},${last.begin.y}]") */

  match last.grow_vec.reverse() {
    .right { 
      if last.begin.x + step > bounds.x - pad
      {
        s.blocked = true
      }
    }
    .left  {
      if last.begin.x - step  < 0
      {
        s.blocked = true
        /* return Direction.left */
      }
    }
    .up    { 
      if last.begin.y - step  < 0
      {
        s.blocked = true
        /* return Direction.up */
      }  
    }
    .down  { 
      if last.begin.y + step  > bounds.y - pad
      {
        s.blocked = true
        /* return Direction.down */
      }
    }
  }

  /* return error("cant move")  */
}

fn (mut s Snake) within_arena(arena_size Vec2) bool {
  last := s.parts[s.parts.len-1]
  pad  := 1

  if last.begin.x > arena_size.x - 1 || last.begin.y > arena_size.y - pad {
    return false
  } 
  else if last.begin.x < 0 - pad || last.begin.y < 0 - pad {
    return false
  }
  else {
    return true
  }
}

fn (mut s Snake) score() u8 {
  mut score := 0
  for i:=0; i < s.parts.len; i++ {
    score += s.parts[i].length
  }
  return u8(score)
}

fn (mut s Snake) hunt(mut place Arena) {

  last   := s.parts[s.parts.len-1]
  mut origin := last.begin
  sight  := last.grow_vec.reverse()

  next := match sight {
    .right{Vec2 { x: origin.x + 1, y: origin.y}}
    .left {Vec2 { x: origin.x - 1, y: origin.y}}
    .up   {Vec2 { x: origin.x, y: origin.y - 1}}
    .down {Vec2 { x: origin.x, y: origin.y + 1}}
  }

  mut player_cells := []Vec2 {}

  for i:=0; i < s.parts.len; i++ {
    for l:=0; l < s.parts[i].length; l++ {
      origin = s.parts[i].begin
      player_cells << match s.parts[i].grow_vec {
        .right { Vec2 { x: origin.x + l, y: origin.y}  }
        .left  { Vec2 { x: origin.x - l, y: origin.y} }
        .up    { Vec2 { x: origin.x, y: origin.y - l} }
        .down  { Vec2 { x: origin.x, y: origin.y + l} }
      }
    }
  }


  for i,food in place.food {
    if place.food[i] == next || place.food[i] in player_cells {
      place.food.delete(i)
      s.parts[s.parts.len-1].length += 1
    } 
  }

}

fn (mut s Snake) collider() {
  mut all_points := []Vec2 {}
  for i:=0; i < s.parts.len; i++ {
    for l:=1; l < s.parts[i].length; l++ {
      origin := s.parts[i].begin
      all_points << match s.parts[i].grow_vec {
        .right { Vec2 { x: origin.x + l, y: origin.y}  }
        .left  { Vec2 { x: origin.x - l, y: origin.y} }
        .up    { Vec2 { x: origin.x, y: origin.y - l} }
        .down  { Vec2 { x: origin.x, y: origin.y + l} }
      }
    }
  }

  if (all_points.len != 0 ) { 
    all_points.delete(all_points.len - 1)
  }

  if s.parts[s.parts.len-1].begin in all_points {
    s.dead = true
  }
}


// PLAYER DIED

fn death_screen(screen_size Vec2,player Snake, arena Arena) {
  message := "You died!"
  tip     := "[press <ESC> to exit or <SPACE> to restart]"
  for y:=0; y < screen_size.y / 2 - 1; y++ {println("")}
  for x:=0; x < screen_size.x / 2 - message.len / 2; x++ {print(" ")}
  println(message)
  for x:=0; x < screen_size.x / 2 - tip.len / 2; x++ {print(" ")}
  println(tip)
}


