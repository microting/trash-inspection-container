FROM node:22-bookworm-slim as node-env
WORKDIR /app
ENV PATH=/app/node_modules/.bin:$PATH
COPY eform-angular-frontend/eform-client ./
RUN apt-get update
RUN apt-get -y -q install ca-certificates
RUN yarn install
RUN yarn build

FROM mcr.microsoft.com/dotnet/sdk:11.0-resolute AS build-env
WORKDIR /app
ARG GITVERSION
ARG PLUGINVERSION

# Copy csproj and restore as distinct layers
COPY eform-angular-frontend/eFormAPI/eFormAPI.Web ./eFormAPI.Web
COPY eform-angular-trash-inspection-plugin/eFormAPI/Plugins/TrashInspection.Pn ./TrashInspection.Pn
RUN dotnet publish eFormAPI.Web -o eFormAPI.Web/out /p:Version=$GITVERSION --runtime linux-x64 --configuration Release
RUN dotnet publish TrashInspection.Pn -o TrashInspection.Pn/out /p:Version=$PLUGINVERSION --runtime linux-x64 --configuration Release

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:11.0-resolute
WORKDIR /app
COPY --from=build-env /app/eFormAPI.Web/out .
RUN mkdir -p ./Plugins/TrashInspection.Pn
COPY --from=build-env /app/TrashInspection.Pn/out ./Plugins/TrashInspection.Pn
COPY --from=node-env /app/dist/browser wwwroot
RUN rm connection.json; exit 0

ENV DEBIAN_FRONTEND=noninteractive
ENV Logging__Console__FormatterName=

RUN mkdir -p /usr/share/man/man1
RUN apt-get update && \
	apt-get -y -q install \
		gss-ntlmssp \
		libxml2-16 \
		libgdiplus \
		libc6-dev \
		libreoffice \
		libreoffice-writer \
		ure \
		libreoffice-java-common \
		libreoffice-core \
		libreoffice-common \
		fonts-opensymbol \
		hyphen-fr \
		hyphen-de \
		hyphen-en-us \
		hyphen-it \
		hyphen-ru \
		fonts-dejavu \
		fonts-dejavu-core \
		fonts-dejavu-extra \
		fonts-droid-fallback \
		fonts-dustin \
		fonts-f500 \
		fonts-fanwood \
		fonts-freefont-ttf \
		fonts-liberation \
		fonts-lmodern \
		fonts-lyx \
		fonts-sil-gentium \
		fonts-texgyre \
		fonts-tlwg-purisa && \
	apt-get -y -q remove libreoffice-gnome && \
	apt -y autoremove && \
	rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/libreoffice && chown -R $APP_UID:$APP_UID /app /opt/libreoffice
ENV HOME=/opt/libreoffice

# .NET's HttpClient performs NTLM auth via GSSAPI (gss-ntlmssp, installed above). NTLM's
# crypto primitives (MD4/RC4/DES) live in OpenSSL 3's "legacy" provider, which Ubuntu Noble
# does not activate by default -- without it AcquireCredentialsHandle fails with a "Crypto
# routine failure" and the NAV NTLM callback returns 401. Activate the legacy provider
# alongside the default one (via .include so the distro's TLS defaults are preserved).
# Required here because the trash-inspection plugin can re-send an inspection to NAV from
# the web API process, not only from the background service.
RUN printf '.include /etc/ssl/openssl.cnf\n[provider_sect]\nlegacy = legacy_sect\n[default_sect]\nactivate = 1\n[legacy_sect]\nactivate = 1\n' > /etc/ssl/openssl-legacy.cnf
ENV OPENSSL_CONF=/etc/ssl/openssl-legacy.cnf

USER $APP_UID

ENTRYPOINT ["dotnet", "eFormAPI.Web.dll"]
