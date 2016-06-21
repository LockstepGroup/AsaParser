using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace AsaParser {
	public class AccessListRule {
        public string Number;
        public string Remark;
        public string Action;
        public string ProtocolType;
        public string Protocol;
        public string SourceType;
        public string Source;
        public string DestinationType;
        public string Destination;
        public string ServiceType;
        public string Service;
        public bool InActive;
    }
}