FROM archlinux:latest AS base

# https://www.archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4
RUN echo 'Server = https://ftp.fau.de/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
RUN pacman --noconfirm -Syu \
 && rm /var/cache/pacman/pkg/* /var/lib/pacman/sync/*


FROM base AS builder

# https://www.archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4
RUN echo 'Server = https://ftp.fau.de/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
RUN pacman --noconfirm -Syu wget

WORKDIR /kubernetes_src
RUN wget -q --show-progress --progress=bar:force https://dl.k8s.io/v1.18.5/kubernetes-src.tar.gz
RUN tar -xf kubernetes-src.tar.gz
RUN rm kubernetes-src.tar.gz

RUN pacman --noconfirm -S go diffutils make rsync
RUN make WHAT=cmd/kubectl -j$(nproc)

# kubectx
WORKDIR /kubectx_src
# (at some point switch to Go implementation, for now it's a Bash script)
RUN wget -q https://github.com/ahmetb/kubectx/releases/download/v0.9.1/kubectx

# shell auto completion
WORKDIR /completions
# bash
RUN /kubernetes_src/_output/bin/kubectl completion bash > kubectl.bash
RUN wget -q https://github.com/ahmetb/kubectx/raw/v0.9.1/completion/kubectx.bash
# fish
RUN wget -q https://github.com/evanlucas/fish-kubectl-completions/raw/7bea3e1/completions/kubectl.fish
RUN wget -q https://github.com/ahmetb/kubectx/raw/v0.9.1/completion/kubectx.fish

WORKDIR /target

RUN echo "Installing everyting to target" \
 && install -Dm755 /kubernetes_src/_output/bin/kubectl -t usr/local/bin/ \
 && install -Dm755 /kubectx_src/kubectx -t usr/local/bin \
 && install -Dm644 /completions/*.bash -t usr/share/bash-completion/completions/ \
 && install -Dm644 /completions/*.fish -t usr/share/fish/completions/ \
 && echo "done"

FROM base AS final

# Add user nautilus
RUN useradd -m -G users -s /bin/fish nautilus

RUN pacman --noconfirm -Sy fish bash-completion \
 && rm /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

COPY --from=builder /target /

USER nautilus
