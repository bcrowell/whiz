%% current
\pdfminorversion=4 % force pdf 1.4 output; http://tex.stackexchange.com/questions/95973/is-pdftex-1-40-13-outputting-malformed-pdfs
\RequirePackage{pdf14}% workaround for a bug in older pdftex; http://tex.stackexchange.com/a/87946/6853
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{problems}
\LoadClass{article}
\usepackage[paperwidth=8.5in,paperheight=11in]{geometry}
\usepackage{amsmath,amssymb,cancel,ifthen,makeidx,graphicx,url,moreverb,multicol}
% moreverb provides listing environment
%
%%%%%%%%%%%%%%%%% figures %%%%%%%%%%%%%%%%%%%
\newcommand{\fig}[1]{ %
	\par\vspace{3mm}\includegraphics{#1} \\
	 \begin{center}\sffamily{Problem chnum-probnum}\normalsize\normalfont\end{center} \par%
}
\newcommand{\anonymousinlinefig}[1]{\includegraphics{#1}}
%%%%%%%%%%%%%%%%% answers %%%%%%%%%%%%%%%%%%%
\newcommand{\solnhdr}[1]{\noindent\textbf{#1}\quad}
\newcommand{\ifchunk}[2]{#2}
\newenvironment{forcesoln}[4]{%
  % #1 is ignored
  \begin{figure*}
  \noindent\textbf{Problem \ref{hw:#4}:}\par
  #2
  \begin{forcetable}{#3}
}{%
  \end{forcetable}
  \end{figure*}
}
\newenvironment{forcetable}[1]{
  \par\noindent\begin{tabular}{|lll|lll|}
  \hline
  & & & \multicolumn{3}{c|}{\emph{equal and opposite force}} \\
  \multicolumn{3}{|c|}{\emph{force acting on #1}} &
  \multicolumn{3}{c|}{\emph{involved in Newton's 3rd law}} \\
  \hline
  \emph{type of} &                & \emph{object exerting} & {} & {} & \emph{object}  \\ 
  \emph{force}	& \emph{direction} & \emph{the force}        & \emph{type}	& \emph{direction} &\emph{exerting it} \\
  \hline
}{%
  \hline
  \end{tabular}
}
%================================ math ================================
\newcommand{\eqquad}{}
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
%========================= AtBeginDocument stuff=========================
\AtBeginDocument{
  \newboolean{hwhavetrailing}
}
