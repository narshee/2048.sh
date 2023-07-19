#!/bin/sh
# 2048 in POSIX Shell

# relevant throughout
# shellcheck disable=SC2046
	# word splitting is required for 'set' to work
# shellcheck disable=SC2294
	# 'eval "$@"' is used for removing leading spaces

# ensure a safe exit
trap 'exit_program' INT QUIT TERM

setup_terminal() {
	# hide cursor
	printf '\033[?25l'
	# clear screen
	printf '\033[2J'
}

exit_program() {
	# show cursor
	printf '\033[?25h'

	exit
}

clean_term() {
	# go to line under the tiles
	printf '\033[6;1H'
	# erase display from cursor
	printf '\033[J'
}

rand() {
	# rand 3
	# "$1" must be (2^d)-1, so all digits are 1 in binary
	# give random number from 0 to "$1"
	# this is actually quite good & fast. didn't think it could be elegant
	# I think the distribution is skewed towards smaller numbers,
	# because the number of bytes read is by definition on avarage 255
	# as the char 'newline' is 1 in 2^8

	# /dev/random is not posix
	read -r x < /dev/random

	# ${#x} # number of bytes read from /dev/random
	echo "$((${#x} & $1))"
}

rewrite_pos_para() {
	# set $(rewrite_pos_para 3 8 "$@")
	# change array elements in "$@"

	pos="$1"
	value="$2"
	shift 2
	array=''

	# select element of array and change it
	n=1
	while [ "$n" -le "$#" ]; do
		if [ "$n" -eq "$pos" ]; then
			array="$array $value"
		else
			# n=13; 'eval \${$n}' expands to ${13}
			# braces '{', '}' are needed for multi-digit positional parameter
			array="$array \${$n}"
		fi
		n="$((n + 1))"
	done

	eval echo "$array"
}

check_populated() {
	# check_populated "$@"
	# check if all tiles are populated

	fully_populated=1
	for i; do
		if [ "$i" -eq 0 ]; then
			fully_populated=0
			break
		fi
	done

	echo "$fully_populated"
}

populate_tile() {
	# populate_tile "$@"
	# we want to set one tile to 2 or 4

	# check if even a tile is unpopulated
	if [ "$(check_populated "$@")" -eq 1 ]; then
		echo "$@"
		return
	fi

	# which array element to populate
	pos="$(($(rand 15) + 1))"

	# if we selected an non-empty tile, do it again until we select an empty one
	while eval [ "\${$pos}" -ne 0 ]; do
		pos="$(($(rand 15) + 1))"
	done

	# select value, 2 or 4
	val="$(($(rand 1) + 1))"

	# change "$@"
	set -- $(rewrite_pos_para "$pos" "$val" "$@")
	echo "$@"
}

print() {
	# print "$@"
	# it prints the score and all tiles

	# go to top of terminal
	printf '\033[1;1H'

	printf 'score: %d %+6d\n' "$score" "$((score - score_prev))"

	line=''

	n=1
	for i; do
		if [ "$power" -eq 1 ]; then
			if [ "$color" -eq 1 ]; then
				if [ "$i" -eq 0 ]; then
					line="$line""$(printf '\033[7m\033[38;5;%dm    ' "$((i + 5))")"
				else
					line="$line""$(printf '\033[7m\033[38;5;%dm%4d' "$((i + 5))" "$((1 << i))")"
				fi
			else
				if [ "$i" -ne 0 ]; then
					i="$((1 << i))"
				fi
				printf '%-5d' "$i"
			fi
		else
			if [ "$color" -eq 1 ]; then
				if [ "$i" -eq 0 ]; then
					line="$line""$(printf '\033[7m\033[38;5;%dm  ' "$((i + 5))")"
				else
					line="$line""$(printf '\033[7m\033[38;5;%dm%2d' "$((i + 5))" "$i")"
				fi
			else
				line="$line""$(printf '%-3d' "$i")"
			fi
		fi

		# print lines
		if [ "$n" -eq 4 ]; then
			printf '%s\n' "$line"
			line=''
			n=1
		else
			n="$((n + 1))"
		fi
	done

	# reset attributes
	printf '\033[0m'
}

check_game_over() {
	# check_game_over "$@"
	# check if in stalemate
	# echo 1 is game over

	# if not all tiles are populated, the game is not over
	if [ "$(check_populated "$@")" -eq 0 ]; then
		echo 0
		return
	fi

	# check if no tile is mergeable
	# column
	c=0
	while [ "$c" -le 8 ]; do
		# row
		r=1
		while [ "$r" -le 3 ]; do

			# check tile to right
			if eval [ "\${$((c + r))}" -eq "\${$((c + r + 1))}" ]; then
				echo 0
				return
			fi

			# check tile below
			if eval [ "\${$((c + r))}" -eq "\${$((c + r + 4))}" ]; then
				echo 0
				return
			fi

			r="$((r + 1))"
		done

		c="$((c + 4))"
	done

	echo 1
}

check_game_state() {
	# check_game_state "$@"
	# check if won or lost

	# check if won
	# check each tile
	for i; do
		# check for 2048
		# 1 << 11 == 2048 == 2^11
		if [ "$i" -eq 11 ]; then
			echo 'You won'
			return
		fi
	done

	# check if game is over
	if [ "$(check_game_over "$@")" -eq 1 ]; then
		echo 'game over'
	fi
}

move_up() {

	# move
	n=1
	# iterate each tiles
	while [ "$n" -le 12 ]; do
		# tile is 0
		if eval [ "\${$n}" -eq 0 ]; then
			i=4
			# check all tiles below
			while [ "$((n + i))" -le 16 ]; do
				# continue when tile is 0
				if eval [ "\${$((n + i))}" -eq 0 ]; then
					i="$((i+4))"
				# move tile if it is not 0
				else
					# copy value to new tile
					set -- $(eval rewrite_pos_para "$n" "\${$((n + i))}" "$@")
					# set old tile to 0
					set -- $(rewrite_pos_para "$((n + i))" 0 "$@")
					break
				fi
			done
		fi

		n="$((n + 1))"
	done

	# merge
	score=0

	n=1
	# check every mergeable tile
	while [ "$n" -le 12 ]; do
		# this condition must be seperate, it's dumb
		if eval [ "\${$n}" -ne 0 ]; then
			# tile below has the same value
			if eval [ "\${$((n + 4))}" -eq "\${$n}" ]; then
				# val is used because \${$n}" can't be in arithmic expansion '$(())'
				eval val="\${$n}"
				# increase score
				score="$((score + (1 << (val + 1))))"
				# increase value of tile
				set -- $(rewrite_pos_para "$n" $((val + 1)) "$@")
				# set old tile to 0
				set -- $(rewrite_pos_para "$((n + 4))" 0 "$@")

				# move all non-empty tiles below the merged merged one up
				if [ "$n" -le 8 ]; then
					# tile below the tile that got set to 0 is 0
					if eval [ "\${$((n + 8))}" -ne 0 ]; then
						i=8
						# check all tiles below
						while [ "$((n+i))" -le 16 ]; do
							# continue when tile is 0
							if eval [ "\${$((n + i))}" -eq 0 ]; then
								i="$((i + 4))"
							# move tile if it is not 0
							else
								# copy value to new tile
								set -- $(eval rewrite_pos_para "$((n + i - 4))" "\${$((n + i))}" "$@")
								# set old tile to 0
								set -- $(rewrite_pos_para "$((n + i))" 0 "$@")
							fi
						done
					fi
				fi

			fi
		fi

		n="$((n + 1))"
	done

	echo "$score" "$@"
}

move_down() {

	# move
	n=16
	while [ "$n" -ge 4 ]; do
		if eval [ "\${$n}" -eq 0 ]; then
			i=4
			while [ "$((n - i))" -ge 1 ]; do
				if eval [ "\${$((n - i))}" -eq 0 ]; then
					i="$((i + 4))"
				else
					set -- $(eval rewrite_pos_para "$n" "\${$((n - i))}" "$@")
					set -- $(rewrite_pos_para "$((n - i))" 0 "$@")
					break
				fi
			done
		fi

		n="$((n - 1))"
	done

	# merge
	score=0

	n=16
	while [ "$n" -gt 4 ]; do
		if eval [ "\${$n}" -ne 0 ]; then
			if eval [ "\${$((n - 4))}" -eq "\${$n}" ]; then
				eval val="\${$n}"
				score="$((score + (1 << (val + 1))))"
				set -- $(rewrite_pos_para "$n" $((val + 1))  "$@")
				set -- $(rewrite_pos_para "$((n - 4))" 0 "$@")

				# move all non-empty tiles above the merged merged one down
				if [ "$n" -gt 8 ]; then
					if eval [ "\${$((n - 8))}" -ne 0 ]; then
						i=8
						while [ "$((n-i))" -ge 1 ]; do
							if eval [ "\${$((n - i))}" -eq 0 ]; then
								i="$((i + 4))"
							else
								set -- $(eval rewrite_pos_para "$((n - i + 4))" "\${$((n - i))}" "$@")
								set -- $(rewrite_pos_para "$((n - i))" 0 "$@")
							fi
						done
					fi
				fi

			fi
		fi

		n="$((n - 1))"
	done

	echo "$score" "$@"
}

move_left() {

	# move
	# column
	c=0
	# iterate each col
	while [ "$c" -le 12 ]; do
		# row
		r=1
		# iterate each tile in col
		while [ "$r" -le 3 ]; do
			# tile is 0
			if eval [ "\${$((c + r))}" -eq 0 ]; then
				i=1
				# check all tiles to the right
				while [ "$((r+i))" -le 4 ]; do
					# continue when tile is 0
					if eval [ "\${$((c + r + i))}" -eq 0 ]; then
						i="$((i + 1))"
					# move tile if it is not 0
					else
						# copy value to new tile
						set -- $(eval rewrite_pos_para "$((c + r))" "\${$((c + r + i))}" "$@")
						# set old tile to 0
						set -- $(rewrite_pos_para "$((c + r + i))" 0 "$@")
						break
					fi
				done
			fi

			r="$((r + 1))"
		done

		c="$((c + 4))"
	done

	# merge
	score=0

	# column
	c=0
	# iterate each col
	while [ "$c" -le 12 ]; do
		# row
		r=1
		# iterate each tile in col
		while [ "$r" -le 3 ]; do
			# tile is not 0
			if eval [ "\${$((c + r))}" -ne 0 ]; then
				# tile to the right has the same value
				if eval [ "\${$((c + r + 1))}" -eq "\${$((c + r))}" ]; then
					eval val="\${$((c + r))}"
					# increase score
					score="$((score + (1 << (val + 1))))"
					# increase value of tile
					set -- $(rewrite_pos_para "$((c + r))" $((val + 1))  "$@")
					# set old tile to 0
					set -- $(rewrite_pos_para "$((c + r + 1))" 0 "$@")

					# move all non-empty tiles right of the merged merged one left
					if [ "$r" -le 2 ]; then
						if eval [ "\${$((c + r + 2))}" -ne 0 ]; then
							i=2
							while [ "$((r + i))" -le 4 ]; do 
								if eval [ "\${$((c + r + i))}" -eq 0 ]; then
									i="$((i + 1))"
								else #move if tile is not 0
									set -- $(eval rewrite_pos_para "$((c + r + i - 1))" "\${$((c + r + i))}" "$@")
									set -- $(rewrite_pos_para "$((c + r + i))" 0 "$@")
								fi
							done
						fi
					fi

				fi
			fi

			r="$((r + 1))"
		done

		c="$((c + 4))"
	done

	echo "$score" "$@"
}

move_right() {

	# move
	c=0
	while [ "$c" -le 12 ]; do
		r=4
		while [ "$r" -ge 1 ]; do
			if eval [ "\${$((c + r))}" -eq 0 ]; then
				i=1
				while [ "$((r - i))" -ge 1 ]; do
					if eval [ "\${$((c + r - i))}" -eq 0 ]; then
						i="$((i + 1))"
					else
						set -- $(eval rewrite_pos_para "$((c + r))" "\${$((c + r - i))}" "$@")
						set -- $(rewrite_pos_para "$((c + r - i))" 0 "$@")
						break
					fi
				done
			fi

			r="$((r - 1))"
		done

		c="$((c + 4))"
	done

	# merge
	score=0

	c=0
	while [ "$c" -le 12 ]; do
		r=4
		while [ "$r" -gt 1 ]; do
			if eval [ "\${$((c + r))}" -ne 0 ]; then
				if eval [ "\${$((c + r - 1))}" -eq "\${$((c + r))}" ]; then
					eval val="\${$((c + r))}"
					score="$((score + (1 << (val + 1))))"
					set -- $(rewrite_pos_para "$((c + r))" $((val + 1))  "$@")
					set -- $(rewrite_pos_para "$((c + r - 1))" 0 "$@")

					# move all non-empty tiles left of the merged merged one right
					if [ "$((c + r - 2))" -ge 1 ]; then
						if eval [ "\${$((c + r - 2))}" -ne 0 ]; then
							i=2
							while [ "$((r - i))" -ge 1 ]; do
								if eval [ "\${$((c + r - i))}" -eq 0 ]; then
									i="$((i + 1))"
								else
									set -- $(eval rewrite_pos_para "$((c + r - i + 1))" "\${$((c + r - i))}" "$@")
									set -- $(rewrite_pos_para "$((c + r - i))" 0 "$@")
								fi
							done
						fi
					fi

				fi
			fi

			r="$((r - 1))"
		done

		c="$((c + 4))"
	done

	echo "$score" "$@"
}

load_highscore() {
	if [ ! -r "$highscore_file" ]; then
		return
	fi
	read -r s < "$highscore_file"

	# select everything after the last ': '
	highscore="${s##*: }"
	# select everything before the last ': '
	highscore_name="${s%%: *}"
}

save_highscore() {
	if [ "$score" -ge "$highscore" ]; then
		printf 'Old highscore: %d by %s\nNew highscore: %d\n' "$highscore" "$highscore_name" "$score"
		printf 'Enter name to override, or [n/no/] to discard\n'

		read -r s

		case "$s" in
			n | no | '') ;; # discard
			*) echo "$s: $score" > "$highscore_file" ;; # save
		esac
	fi
}

help() {
	printf 'Usage: %s %s\n' "$0" '[options...]
 -h, --help                Print this
 -e, --exponent            Use exponents instead of powers
 -n, --no-color            No color mode
 -f, highscore-file=<file> Highscore-file. Default is highscore.txt

Movement: wasd, hjkl, arrow keys, 8462 & ENTER
Reset: r & ENTER
Quit: q & ENTER, Ctrl-C to exit without saving highscore
Press a key for a direction and ENTER
You can press multiple keys,
but only the last pressed key is used'
}

handle_options() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-h | --help)
				help
				exit
				;;
			-n | --no-color | --no-colour)
				color=0
				;;
			-e | --exponent)
				power=0
				;;
			-f)
				shift
				highscore_file="$1"
				;;
			'--highscore-file='*)
				highscore_file="${1#*=}"
				;;
			*)
				;;
		esac
		shift
	done
}

check_dev_random() {
	# if /dev/random not readable
	if [ ! -r '/dev/random' ]; then
		printf '%s\n' '/dev/random is not readable. It can be replaced with another rng file'
		exit 1
	fi
}

init_tiles() {
	# set init

	set -- 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0

	set -- $(populate_tile "$@")
	set -- $(populate_tile "$@")

	echo "$@"
}

init() {
	score=0
	score_prev=0
	highscore=0
	highscore_name=''
	moves=0

	load_highscore
	setup_terminal
	print "$@"
}

main() {
	color=1
	power=1
	highscore_file=highscore.txt

	handle_options "$@"
	check_dev_random

	set -- $(init_tiles)
	init "$@"

	while read -r input; do

		# "${input%?}" removes last char
		# "${input#"${input%?}"}" just keeps last char
		case "${input#"${input%?}"}" in
			w | A | k | 8)
				set -- $(move_up "$@")
				score="$((score + $1))"
				shift
				;;
			a | D | h | 4)
				set -- $(move_left "$@")
				score="$((score + $1))"
				shift
				;;
			s | B | j | 2)
				set -- $(move_down "$@")
				score="$((score + $1))"
				shift
				;;
			d | C | l | 6)
				set -- $(move_right "$@")
				score="$((score + $1))"
				shift
				;;
			r)
				set -- $(init_tiles)
				init "$@"
				continue
				;;
			q)
				save_highscore
				exit_program
				;;
			*)
				clean_term
				continue
				;;
		esac

		set -- $(populate_tile "$@")
		print "$@"
		clean_term
		score_prev="$score"
		moves="$((moves + 1))"

		# end game
		return_vars="$(check_game_state "$@")"
		if [ "$return_vars" ]; then
			echo "$return_vars in $moves moves"
			save_highscore
			exit_program
		fi
	done
}

main "$@"
