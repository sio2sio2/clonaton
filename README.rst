********
Clonatón
********

¿Qué es clonatón?
*****************
Una aplicación que permite generar arranques de red con `syslinux
<https://www.syslinux.org>`_ e incluye entre sus entradas predeterminadas un
servicio de clonaciones con `clonezilla <https://clonezilla.org/>`_.

Posibilita:

+ En lo relativo a la instalación:

  * Integrar la aplicación en un servidor que ya disponga de servicio |DHCP| y
    al que se quiera añadir la capacidad de servir SS.OO. por red al resto de
    ordenadores.

  * Montar la aplicación en un ordenador independiente en aquellas redes que ya
    dispongan de un servicio |DHCP| que no se desea (o no se puede) modificar

+ En lo relativo a la clonación:

  * Clasificar las imágenes por redes (aulas) y tipos de ordenador, de manera
    que sólo sean visibles desde el ordenador de un aula determina, aquellas
    imágenes que le sean apropiadas.

  * Realizar clonaciones unicast, multicast y broadcast.

  * Realizar todas las operaciones relativas a la creación, restauración y
    gestión de imágenes desde el propio menú de arranque ofrecido por
    :program:`syslinux`.

Requisitos
**********
:program:`clonaton` exige la combinación de varios servicios, por lo que
necesita varios programas:

* Un servicio que ofrezca la información de arranque. Esta labor puede hacerla
  tanto un servidor |DHCP|, que junto a la configuración la red puede
  proporcionar la información de arranque, como un servidor |PXE|, que sólo
  ofrece la segunda\ [#]_. En el segundo caso, es forzoso que el servidor sea
  :program:`dnsmasq`, mientras que en el primer caso, podemos optar por los
  servidores más habituales: el `del ¡ISC
  <https://www.isc.org/downloads/dhcp/>`_, el minimalista `udhcpd
  <https://busybox.net/downloads/BusyBox.html#udhcpd>` o el propio
  :program:`dnsmasq`. A menos que haya una razón poderosa para no hacerlo, lo
  recomendable es usar también :program:`dnsmasq` en este caso, ya que tiene la
  ventaja de integrar otros servicios necesarios.

* Un servicio |TFTP| para la descarga de ficheros de arranque en la etapa más
  temprana. Puede usarse cualquier servidor, incluídos aquellos que no soportan
  el :rfc:`2348` y, por tanto, no son capaces de servir ficheros de más de 32MB.
  :program:`dnsmasq` incluye este servicio, así que usarlo nos exime de instalar
  (y configurar por nuestra cuenta) un servidor independiente para esta tarea.

* Un servidor |HTTP| que permita la ejecución de codigo |PHP|.
  :program:`clonaton` incluye la configuración necesaria para `nginx
  <http://nginx.org>`_. Puede usar otro servidor como `apache
  <https://www.apache.org/>`_, pero tendrá usted mismo que configurarlo
  traduciendo la configuración que se ofrece para :program:`nginx`.

* :program:`syslinux` (y :program:`pxelinux`)

* Opcionalmente, un servicio |DNS| si se opta por referir al servidor mediante
  un nombre en vez de una dirección *IP*. Esto puede ser especialmente útil
  si el servidor esta enganchado a varias redes.

Para ofrecerse el sevicio de clonaciones son necesarios, además:

* Un servidor |SSH|.

* Un servidor |NFS| que exporte el directorio donde se almacenan las imágenes.

* :command:`sudo`.

* :command:`udpcast`.

Preinstalación
**************
La aplicación se proporciona mediante un fichero *.tar.xz* que puede
desempaquetarse::

   # tar -axvf clonaton.tar.xz
   # cd clonaton

Llegados a este punto tenemos dos posibilidades de instalación:

* Instalación directa.
* Si estamos en *debian* o una derivada, generación del paquete *deb*
  e instalación a través de él::

   # make deb

  El paquete se encontrará en el directorio padre.

La ventaja de este segundo método es doble:

#. No necesitamos instalar previamente ningún programa, ya que el
   gestor de paquetes se encarga de hacer el trabajo.
#. Es posible configurar y reiniciar los servicios automáticamente.

Instalación
***********

Mediante paquete ``.deb``
=========================

.. rubric:: Guía del que ni sabe ni quiere saber

Aplicable si la máquina no tiene instalado ningún servicio relacionado
previamente (|DHCP|, |TFTP|, |HTTP| y |NFS|).

#. Instalar::

      # dpkg -i clonaton_0.1pre_all.deb

#. Instalar dependencias y arrancar la configuración::

      # apt-get -f install

#. Contestar a las preguntas con ``Enter``, ``Enter``, ``Enter`` salvo:

   * La primera relativa a la forma en la que actúa :program:`dnsmasq`: si no
     hay ya servidor |DHCP| elija la primera opción; si ya lo hay, escoja la
     segunda.

     .. warning:: En caso de que escoja la segunda opción, tenga en cuenta
        que el servidor |DHCP| informa a los clientes de cuál es el servidor
        |DNS|. La configuración de este último debe hacerse de forma que
        *pxeserver* resuelva a todas las *IPs* del servidor de clonaciones.

   * Debe dar un nombre y una descripción a las aulas a las que quiere dar
     servicio.

   * Conteste que **sí** a la pregunta de si desea configurar automáticamente
     los servicios y reiniciarlos.

#. Añada un usuario al grupo *clonaton*::

   # adduser usuario_clonador clonaton

.. rubric:: Guía comentada

#. Instalar manualmente el paquete::

      # dpkg -i clonaton_0.1pre_noarch.deb

#. Es probable que no se satisfagan todas las dependencias, por lo que el
   paquete quedará a medio instalar y sin configurar. Para solucionarlo::

      # apt-get -f install

   .. note:: Si no se especifica nada más, se instalará :program:`dnsmasq`, ya
      que la aplicación prefiere :program:`dnsmasq` sobre cualquier otro
      servidor |DHCP|, ya que:
   
      * Si deseamos integrar la aplicación con el servidor |DHCP|,
        :program:`dnsmasq` es también capaz de proporcionar |TFTP| y |DNS| y
        evita la instalación de servidores independientes para estas dos
        tareas.

      * Si nuestra intención es montar un servicio |PXE| y que el |DHCP|
        lo proporcione otro servidor (o dispositivo de red) independiente,
        entonces sólo :program:`dnsmasq` puede resolver esta función
        (*proxyDHCP*).

   .. note:: Si ya se había instalado el servidor del |ISC|, entonces no
      se instalará :program:`dnsmasq` y la aplicación entenderá que deseamos
      integrar los servicios |DHCP| y |PXE|.

.. _preguntas-instalacion:

#. Al instalar las dependecias, la instalación arrancará el instalador que
   realizará una serie de preguntas a fin de dejar preparada la aplicación para
   su uso. En lo relativo a estas preguntas es conveniente aclarar lo siguiente:

   * Si el sistema sólo tiene instalado :program:`dnsmasq`, se nos preguntará si
     este servicio proporcionará también el |DHCP| o se limita a proporcionar
     |PXE|. La respuesta dependerá de si proyecta que este servidor gestione las
     direcciones de red y, por tanto, deba estar permanentemente dando servicio,
     o si, simplemente, quiere montar un servidor marginal que cumpla
     estrictamente con la labor clonatoria.

   * El nombre requerido es aquel que escogerá para identificar al servidor. Si
     configura usted por su cuenta el servicio |DNS|, debe hacer que tal nombre
     resuelva a la |IP| del servidor y tendrá que proporcionar dominios de
     búsqueda a los clientes para que puedan contactar con el servidor haciendo
     uso del nombre y no incluyendo el dominio. Por tanto, si escoge como nombre
     el sugerido (*pxeserver*), desde un cliente la orden::

         $ host pxeserver

     debe resolver a la *IP* del servidor. Si usa :program:`dnsmasq` y deja que
     éste se encargue del |DNS| tendrá el trabajo hecho.

     .. note:: Si está montando un servidor |PXE| independiente,
        :program:`dnsmasq` podría encargándose del |DNS|, pero tendrá que
        configurar el servidor |DHCP| para que informe a los clientes de que el
        nuevo servidor es el servidor |DNS|. Si no le es posible alterar el
        servicio |DHCP|, entonces no tendrá más remedio que usar una *IP* en vez
        de un nombre para contestar a la pregunta.

   * Establezca los directorios que compartirá por |TFTP| y |NFS|. El segundo
     contedrá las imágenes creadas, así que requerirá encontrarse en una
     partición grande. El primero contiene los ficheros compartidos por |TFTP|
     en la primera etapa del arranque, pero también los ficheros compartidos por
     |HTTP| en la segunda etapa y en la carga de los sistemas operativos.

   * El configurador detecta todas las redes a las que está conectado el
     servidor y le pida que dé un nombre y una descripción a cada una de ellas.
     Si no desea que alguna de las redes participe, deje en blanco el nombre. En
     caso de que el servidor actúe de |DHCP| por las redes anónimas no se
     servirán direcciones.

   * El instalador, en principio, deja las configuraciones necesarias para
     configurar los distintos servicios dentro de :file:`/etc/clonaton/configs`.
     Ahora bien, si no tenía configurado previamente ningún servicio puede
     permitir sin miedo que el configurador traslade estos ficheros a la
     ubicación final que deben tener para configurar de modo efectivo y
     automático todos los servicios.

#. La instalación crea el grupo *clonaton* en el que se pueden incluir
   todos los usuarios que desee que tengan permiso para crear y manipular
   imnágenes.

Mediante el instalador general
==============================

Postinstalación
***************

Comprobación del servicio
=========================
Una vez completada la instalación y configuración, es conveniente probar
**desde un cliente** que todos los servicios van bien:

* Compruebe que recibe *IP* dinámica.

* Pruebe la conectividad al servidor usando el nombre::

   $ ping pxeserver

  Adicionalmente, puede comprobar si el cliente tiene bien configurada la
  puerta de enlace::

   $ ping www.google.es

* Acceda por |SSH| al servidor con un usuario que pertenezca al grupo
  *clonaton*::

   $ ssh usuario_de_clonaton@pxeserver

* Descargue :file:`lpxelinux.0` por |TFTP|::

   $ echo "get bios/lpxelinux.0" | tftp pxelinux

* Intente montar con |NFS| el directorio :file:`/srv/nfs/images`::

   # mount -t nfs -o ro,vers=3 pxeserver:/srv/nfs/images /mnt

* Pruebe a obtener el menú de arranque::

   $ wget -qO - http://pxeserver/boot/bios/pxelinux.cfg/01-00-11-22-33-44-55


Apañando SliTaZ
===============
*SliTaZ* no proporciona a través de su página web, la versión *base* de su
distribución, que es la mínima para que sea operativa y que es suficiente para
la ejecución de algunas de las tareas que realiza el servicio de clonaciones.

Por eso motivo, el instalador usa la versión *core* que dispone de entorno
gráfico, pero es más pesada. Dada la facilidad para generar a partir de una
versión la otra, es recomendable hacer lo siguiente:

#. Arrancar a través del menú la *SliTaZ* gráfica.
#. Hacerse administrador y realizar lo siguiente::

    $ su -  # La contraseña es root.
    # mkdir -p /home/slitaz/flavors
    # cd /home/slitaz/flavors
    # tazlito get-flavor base
    # tazlito gen-distro

#. Completadas estas acciones, se tendrá en :file:`/home/slitaz/5.0/distro`
   la imagen *ISO* de la slitaz base. Como nos interesa esclusivamente, su
   sistema de ficheros, podemos extraerlo de la imagen y subirlo al
   servidor::

    # mount -o ro,loop /home/slitaz/5.0/distro/slitaz-base.iso /mnt
    # scp /mnt/boot/rootfs.gz usuario_de_clonaton@pxeserver:/tmp
    # poweroff

#. De vuelta en el servidor, debemos copiar el fichero en 
   :file:`/srv/tftp/ssoo/slitaz`::

    # mv -f /tmp/rootfs.gz /srv/tftp/ssoo/slitaz

Personalización
***************

Estética
========

Manipulación de entradas
========================

.. rubric:: Notas al pie

.. [#] Es obvio que, además, en algún dispositivo de la red debe existir un
   servidor |DHCP| que ofrezca la configuración de red y el servidor |PXE|
   se limita a suplementarla añadiendo la información de arranque. Implementar
   este caso es el que requiere un escenario en que ya existe una servicio
   |DHCP| y una red completamente funcional, y se quiere montar un servicio de
   clonaciones en una máquina aparte.

.. |DHCP| replace:: :abbr:`DHCP (Dynamic Host Configuration Protocol)`
