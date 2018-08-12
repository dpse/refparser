# Overview

Utility for parsing LaTeX-style references in Markdown for use with [Pandoc](https://pandoc.org/).

Sample input:
```
# Header 1

\label{h1}

\label[0]{a}
\label[0]{b}
\label[1]{c}
\label[]{d}
\label[]{e}
\label[0]{f}

Should be 1 2 1 1 2 3
\ref{a} \ref{b} \ref{c} \ref{d} \ref{e} \ref{f}

![This is the \label{fig_test1} caption](/url/of/image.png)

## Header 1.1

![This is the caption](/url/of/image.png)

See Figure \ref{fig_test1} and \ref{fig:1} but not \ref{foo}.

## Header 1.2

![\label{fig_test2} caption](/url/of/image.png)
Text testxt text. see section \ref{h2}.

### Header 1.2.1

\label{test}

![\label{fig_test3}](/url/of/image.png)

### Header 1.2.2

See subsection (1.2.1 = \ref{test})

![An exemplary \label{fig:1} image](example-image.jpg)

# Header 2

\label{h2}

Text testxt text. see section \ref{h1}.

# Header 3

## Header 3.1
```

Sample output:
```
# 1 Header 1 {#section-1}

Should be 1 2 1 1 2 3
1 2 1 1 2 3

![Figure 1: This is the caption](/url/of/image.png)

## 1.1 Header 1.1 {#section-1.1}

![Figure 2: This is the caption](/url/of/image.png)

See Figure 1 and 5 but not \ref{foo}.

## 1.2 Header 1.2 {#section-1.2}

![Figure 3: caption](/url/of/image.png)
Text testxt text. see section [2](#section-2).

### 1.2.1 Header 1.2.1 {#section-1.2.1}

![Figure 4](/url/of/image.png)

### 1.2.2 Header 1.2.2 {#section-1.2.2}

See subsection (1.2.1 = [1.2.1](#section-1.2.1))

![Figure 5: An exemplary image](example-image.jpg)

# 2 Header 2 {#section-2}

Text testxt text. see section [1](#section-1).

# 3 Header 3 {#section-3}

## 3.1 Header 3.1 {#section-3.1}
```