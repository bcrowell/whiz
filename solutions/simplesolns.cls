\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{simplesolns}

\LoadClass[10pt]{article}

\RequirePackage{amssymb,moreverb,xr,float,ifthen,multicol}
\RequirePackage[leqno]{amsmath}
\newcommand{\fig}[1]{ %
	\par\vspace{3mm}\includegraphics{\chdir/figs/#1} \\
	 \begin{center}\sffamily{Problem \chnum-\probnum}\normalsize\normalfont\end{center} \par%
}
\newcommand{\eqquad}{}  
% I used to have flying punctuation after displayed math, e.g.,  
%      x=7 \qquad .  
% I decided that looked bad, so I replaced the qquads with this do-nothing macro.  

%================================ math ================================
%-------------------- differentials, vectors not in italics, units -------------------
\newcommand{\der}{\textup{d}}
\newcommand{\myvec}[1]{\mathbf{#1}}
\newcommand{\myunit}[1]{\textup{#1}}
\newcommand{\kgunit}{\myunit{kg}}
\newcommand{\gunit}{\myunit{g}}
\newcommand{\munit}{\myunit{m}}
\newcommand{\sunit}{\myunit{s}}
\newcommand{\degunit}{\ensuremath{\,^{\circ}}}
\newcommand{\degcunit}{\degunit\textup{C}}
\newcommand{\junit}{\myunit{J}}
\newcommand{\nunit}{\myunit{N}}
\newcommand{\kunit}{\myunit{K}}
\newcommand{\unitdot}{\!\cdot\!}
\newcommand{\momunit}{\kgunit\unitdot\munit/\sunit}
\newcommand{\btheta}{\boldsymbol{\theta}}
\newcommand{\bomega}{\boldsymbol{\omega}}
\newcommand{\balpha}{\boldsymbol{\alpha}}
\newcommand{\btau}{\boldsymbol{\tau}}
\newcommand{\bell}{\boldsymbol{\ell}}
%-------------------- math in sans-serif text -------------------
% $...\zs{x}...$ -- italic, for use when I need symbol font mixed in
% $...\zu{x}...$ -- upright, e.g. for digits and things in sans
% See DeclareMathAlphabet near top, and p. 177 of LaTeX companion, for \ms{}.
% Note: don't put superscripts or subscripts inside these, or any math commands
% at all.
% They can all be used outside of math mode in examples or other sans-serif
% text, but won't necessarily produce the right results in serif text,
% since zs forces sans serif. So when cutting and pasting from example text
% into serif text, have to change zs's.
\newcommand{\zs}[1]{\ensuremath{\ms{#1}}}
\newcommand{\zu}[1]{\textup{#1}}
\newcommand{\zb}[1]{\textbf{#1}}
\newcommand{\vc}[1]{\textbf{#1}}
\newcommand{\massenergy}{\mathcal{E}}% If I change this, need to change the verbal description of it in SN 7 and LM 26.
%========================= graphicx package=========================
\usepackage{graphicx}

\AtBeginDocument{
  %========================= pdf stuff=========================
	\DeclareGraphicsExtensions{.pdf,.png}
}
