# frozen_string_literal: true

task :socat do
  sh 'socat -x PTY,link=$PWD/ttyHU,rawer PTY,link=$PWD/ttyCDC,rawer'
end
