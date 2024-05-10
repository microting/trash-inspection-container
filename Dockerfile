FROM node:20-bookworm-slim as node-env
WORKDIR /app
ENV PATH /app/node_modules/.bin:$PATH
COPY eform-angular-frontend/eform-client ./
RUN apt-get update
RUN apt-get -y -q install ca-certificates
RUN yarn install
RUN yarn build

FROM mcr.microsoft.com/dotnet/sdk:8.0-jammy AS build-env
WORKDIR /app
ARG GITVERSION
ARG PLUGINVERSION

# Copy csproj and restore as distinct layers
COPY eform-angular-frontend/eFormAPI/eFormAPI.Web ./eFormAPI.Web
COPY eform-angular-trash-inspection-plugin/eFormAPI/Plugins/TrashInspection.Pn ./TrashInspection.Pn
RUN dotnet publish eFormAPI.Web -o eFormAPI.Web/out /p:Version=$GITVERSION --runtime linux-x64 --configuration Release
RUN dotnet publish TrashInspection.Pn -o TrashInspection.Pn/out /p:Version=$PLUGINVERSION --runtime linux-x64 --configuration Release

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy
WORKDIR /app
COPY --from=build-env /app/eFormAPI.Web/out .
RUN mkdir -p ./Plugins/TrashInspection.Pn
COPY --from=build-env /app/TrashInspection.Pn/out ./Plugins/TrashInspection.Pn
COPY --from=node-env /app/dist wwwroot
RUN rm connection.json; exit 0

ENV DEBIAN_FRONTEND noninteractive
ENV Logging__Console__FormatterName=

RUN mkdir -p /usr/share/man/man1mkdir -p /usr/share/man/man1
RUN apt-get update && \
	apt-get -y -q install \
		libxml2 \
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

RUN adduser --home=/opt/libreoffice --disabled-password --gecos "" --shell=/bin/bash libreoffice

ENTRYPOINT ["dotnet", "eFormAPI.Web.dll"]
